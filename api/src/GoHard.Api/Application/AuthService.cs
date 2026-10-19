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

    /// <summary>
    /// How long after a rotation the immediately previous refresh token may still obtain the replacement it was rotated
    /// to, when that replacement is still unused (a refresh the server accepted whose response the phone never received).
    /// Counted from the rotation; retries do not extend it. 0 turns recovery off. docs/ARCHITECTURE.md › Sessions.
    /// </summary>
    public int RefreshRecoverySeconds { get; set; } = 300;
    public SymmetricSecurityKey Key => new(Encoding.UTF8.GetBytes(SigningKey));
}

public sealed record RegisterRequest(string Email, string Password, string DisplayName);
public sealed record LoginRequest(string Email, string Password);
public sealed record RefreshRequest(string RefreshToken);
public sealed record ProfileDto(Guid UserId, string Email, string DisplayName, string Appearance, string LoadUnit,
    bool RemindersEnabled, string? ReminderLocalTime, int Revision, int? CalorieGoal = null, int? ProteinGoal = null,
    int? WaterGoalMl = null, bool? ShowWater = null, bool? ShowCarbs = null, bool? ShowFat = null);
public sealed record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAtUtc, string RefreshToken, ProfileDto Profile);
public sealed record AuthError(string Code);

public sealed class AuthService(GoHardDb db, AuthOptions options)
{
    public const string StampClaim = "stamp";
    private static readonly PasswordHasher<User> Hasher = new();

    public static ProfileDto ToProfile(User u) =>
        new(u.Id, u.Email, u.DisplayName, u.Appearance, u.LoadUnit, u.RemindersEnabled, u.ReminderLocalTime, u.Revision, u.CalorieGoal, u.ProteinGoalG, u.WaterGoalMl,
            u.ShowWater, u.ShowCarbs, u.ShowFat);

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

    /// <summary>
    /// Rotates the refresh token: the presented one is revoked and replaced, once. The replacement is derived from the
    /// presented token with a server-only key, so it can be given again without storing it: when a phone retries with the
    /// immediately previous token within <see cref="AuthOptions.RefreshRecoverySeconds"/> of the rotation and the
    /// replacement has not been used, logged out or expired, it receives that same replacement (and a new access token).
    /// Anything else is rejected as before: unknown, expired, logged out, older than the immediate predecessor, a
    /// replacement already used, a deleted account, or after the window.
    /// </summary>
    public async Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken ct)
    {
        var presented = refreshToken ?? "";
        var now = DateTime.UtcNow;
        var token = await db.RefreshTokens.AsNoTracking().FirstOrDefaultAsync(t => t.TokenHash == HashToken(presented), ct);
        if (token is null || token.ExpiresAtUtc <= now) return null;
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == token.UserId, ct);
        if (user is null) return null;
        var replacement = Successor(presented);
        var replacementHash = HashToken(replacement);

        if (token.RevokedAtUtc is null)
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var replacementId = Guid.NewGuid();
            // Only one request rotates a token: a concurrent one waits on this row, then finds it rotated and recovers.
            var claimed = await db.RefreshTokens.Where(t => t.Id == token.Id && t.RevokedAtUtc == null)
                .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAtUtc, now).SetProperty(t => t.ReplacedById, replacementId), ct);
            if (claimed == 1)
            {
                db.RefreshTokens.Add(new RefreshToken
                {
                    Id = replacementId, UserId = user.Id, TokenHash = replacementHash, ExpiresAtUtc = now.AddDays(options.RefreshTokenDays),
                });
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                return Issue(user, replacement);
            }
            await tx.RollbackAsync(ct);
            token = await db.RefreshTokens.AsNoTracking().FirstAsync(t => t.Id == token.Id, ct);
        }

        // Recovery: rotated (not logged out), within the window counted from the rotation, replacement still unused.
        if (token.ReplacedById is not { } replacedBy || token.RevokedAtUtc is not { } rotatedAt
            || options.RefreshRecoverySeconds <= 0 || now - rotatedAt > TimeSpan.FromSeconds(options.RefreshRecoverySeconds)) return null;
        var next = await db.RefreshTokens.AsNoTracking().FirstOrDefaultAsync(t => t.Id == replacedBy, ct);
        if (next is null || next.RevokedAtUtc is not null || next.ExpiresAtUtc <= now || next.UserId != token.UserId || next.TokenHash != replacementHash)
            return null;
        return Issue(user, replacement);
    }

    /// <summary>The replacement for a refresh token: HMAC of it under a key only the server has (derived from the signing
    /// key, so every instance and restart agrees). Nothing recoverable is stored; rows keep only hashes.</summary>
    private string Successor(string presented) =>
        Convert.ToBase64String(HMACSHA256.HashData(SHA256.HashData(Encoding.UTF8.GetBytes("gohard.refresh-chain|" + options.SigningKey)), Encoding.UTF8.GetBytes(presented)));

    public async Task LogoutAsync(Guid userId, string refreshToken, CancellationToken ct)
    {
        var hash = HashToken(refreshToken ?? "");
        await db.RefreshTokens.Where(t => t.UserId == userId && t.TokenHash == hash && t.RevokedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAtUtc, DateTime.UtcNow), ct);
    }

    /// <summary>A new sign-in: a fresh random refresh token, starting a new chain.</summary>
    private async Task<AuthResponse> IssueAsync(User user, CancellationToken ct)
    {
        var refresh = NewSecret();
        db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(), UserId = user.Id, TokenHash = HashToken(refresh),
            ExpiresAtUtc = DateTime.UtcNow.AddDays(options.RefreshTokenDays),
        });
        await db.SaveChangesAsync(ct);
        return Issue(user, refresh);
    }

    /// <summary>A new access token (with the account's current security stamp) beside the given refresh token.</summary>
    private AuthResponse Issue(User user, string refresh)
    {
        var expires = DateTime.UtcNow.AddMinutes(options.AccessTokenMinutes);
        var jwt = new JwtSecurityToken(options.Issuer, options.Audience,
            [new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()), new Claim(StampClaim, user.SecurityStamp)],
            expires: expires, signingCredentials: new SigningCredentials(options.Key, SecurityAlgorithms.HmacSha256));
        return new(new JwtSecurityTokenHandler().WriteToken(jwt), expires, refresh, ToProfile(user));
    }

    private static string NewSecret() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    private static string HashToken(string token) => Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
