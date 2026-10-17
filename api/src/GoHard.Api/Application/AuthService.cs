using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using GoHard.Api.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace GoHard.Api.Application;

public sealed class AuthOptions
{
    public string Issuer { get; set; } = "";
    public string Audience { get; set; } = "";
    public string SigningKey { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 30;
    public int RefreshTokenDays { get; set; } = 60;
    public SymmetricSecurityKey Key => new(Encoding.UTF8.GetBytes(SigningKey));
}

public sealed record RegisterRequest(string Email, string Password, string DisplayName);
public sealed record LoginRequest(string Email, string Password);
public sealed record RefreshRequest(string RefreshToken);
public sealed record ProfileDto(Guid UserId, string Email, string DisplayName, string Appearance, string LoadUnit,
    bool RemindersEnabled, string? ReminderLocalTime, int Revision, int? CalorieGoal = null, int? ProteinGoal = null,
    int? WaterGoalMl = null);
public sealed record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAtUtc, string RefreshToken, ProfileDto Profile);
public sealed record AuthError(string Code);

public sealed class AuthService(GoHardDb db, AuthOptions options)
{
    public const string StampClaim = "stamp";
    private static readonly PasswordHasher<User> Hasher = new();

    public static ProfileDto ToProfile(User u) =>
        new(u.Id, u.Email, u.DisplayName, u.Appearance, u.LoadUnit, u.RemindersEnabled, u.ReminderLocalTime, u.Revision, u.CalorieGoal, u.ProteinGoalG, u.WaterGoalMl);

    public async Task<(AuthResponse? Ok, string? Error)> RegisterAsync(RegisterRequest r, CancellationToken ct)
    {
        var email = (r.Email ?? "").Trim().ToLowerInvariant();
        var name = (r.DisplayName ?? "").Trim();
        if (email.Length is < 3 or > 320 || !email.Contains('@')) return (null, "INVALID_EMAIL");
        if ((r.Password ?? "").Length < 8) return (null, "WEAK_PASSWORD");
        if (name.Length is 0 or > 80) return (null, "INVALID_DISPLAY_NAME");
        if (await db.Users.AnyAsync(u => u.Email == email, ct)) return (null, "EMAIL_IN_USE");

        var user = new User
        {
            Id = Guid.NewGuid(), Email = email, DisplayName = name,
            SecurityStamp = NewSecret(), CreatedAtUtc = DateTime.UtcNow,
        };
        user.PasswordHash = Hasher.HashPassword(user, r.Password!);
        db.Users.Add(user);
        db.TrainingContexts.Add(new TrainingContext { UserId = user.Id, Revision = 1 });
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException) { return (null, "EMAIL_IN_USE"); } // lost the unique-email race
        return (await IssueAsync(user, ct), null);
    }

    public async Task<AuthResponse?> LoginAsync(LoginRequest r, CancellationToken ct)
    {
        var email = (r.Email ?? "").Trim().ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email, ct);
        if (user is null || !VerifyPassword(user, r.Password)) return null;
        return await IssueAsync(user, ct);
    }

    public static bool VerifyPassword(User user, string? password) =>
        !string.IsNullOrEmpty(password) &&
        Hasher.VerifyHashedPassword(user, user.PasswordHash, password) != PasswordVerificationResult.Failed;

    /// <summary>Rotates the refresh token: the presented one is revoked and a new pair is issued.</summary>
    public async Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken ct)
    {
        var hash = HashToken(refreshToken ?? "");
        var token = await db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (token is null || token.RevokedAtUtc is not null || token.ExpiresAtUtc <= DateTime.UtcNow) return null;
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == token.UserId, ct);
        if (user is null) return null;
        token.RevokedAtUtc = DateTime.UtcNow;
        return await IssueAsync(user, ct);
    }

    public async Task LogoutAsync(Guid userId, string refreshToken, CancellationToken ct)
    {
        var hash = HashToken(refreshToken ?? "");
        await db.RefreshTokens.Where(t => t.UserId == userId && t.TokenHash == hash && t.RevokedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAtUtc, DateTime.UtcNow), ct);
    }

    private async Task<AuthResponse> IssueAsync(User user, CancellationToken ct)
    {
        var expires = DateTime.UtcNow.AddMinutes(options.AccessTokenMinutes);
        var jwt = new JwtSecurityToken(options.Issuer, options.Audience,
            [new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()), new Claim(StampClaim, user.SecurityStamp)],
            expires: expires, signingCredentials: new SigningCredentials(options.Key, SecurityAlgorithms.HmacSha256));
        var refresh = NewSecret();
        db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(), UserId = user.Id, TokenHash = HashToken(refresh),
            ExpiresAtUtc = DateTime.UtcNow.AddDays(options.RefreshTokenDays),
        });
        await db.SaveChangesAsync(ct);
        return new(new JwtSecurityTokenHandler().WriteToken(jwt), expires, refresh, ToProfile(user));
    }

    private static string NewSecret() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    private static string HashToken(string token) => Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
