using System.Buffers.Binary;
using System.Globalization;
using MailAddress = System.Net.Mail.MailAddress;
using System.Security.Cryptography;
using System.Text;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace GoHard.Api.Application.AccountEmail;

/// <summary>
/// Configuration section "Email" (GOHARD_Email__*). docs/AUTHENTICATION_EMAIL.md › Configuration. Empty Provider = no
/// sender: every email route says EMAIL_UNAVAILABLE and nothing is queued.
/// </summary>
public sealed class EmailOptions
{
    public const string Resend = "Resend", Capture = "Capture";
    public string Provider { get; set; } = "";
    public string ResendApiKey { get; set; } = "";
    public string ResendBaseUrl { get; set; } = "https://api.resend.com/";
    public string FromAddress { get; set; } = "";
    public string FromName { get; set; } = "GoHard";
    /// <summary>Optional. Only an address that really receives replies.</summary>
    public string ReplyTo { get; set; } = "";
    /// <summary>Server-only key the codes are derived from (and addresses hashed with). At least 32 characters.</summary>
    public string CodeSecret { get; set; } = "";
    public int CodeMinutes { get; set; } = 10;
    public int MaxAttempts { get; set; } = 5;
    public int CooldownSeconds { get; set; } = 60;
    public int MaxSendsPerHour { get; set; } = 5;
    public int DeliveryBudgetPerHour { get; set; } = 200;
    public int ResetGrantMinutes { get; set; } = 10;
    public int PerIpPerHour { get; set; } = 60;
    public int MaxDeliveryAttempts { get; set; } = 5;
    public int SendTimeoutSeconds { get; set; } = 15;
    /// <summary>Tests turn the background loop off and run passes themselves.</summary>
    public bool WorkerEnabled { get; set; } = true;
    public bool Configured => Provider is Resend or Capture;
}

public sealed record CodeRequest(string? Email, string? Language);
public sealed record LanguageRequest(string? Language);
public sealed record CodeVerifyRequest(string? Email, string? Code);
public sealed record CodeConfirmRequest(string? Code);
public sealed record ResetCompleteRequest(string? ResetToken, string? NewPassword, string? Language);
public sealed record PasswordChangeRequest(string? CurrentPassword, string? NewPassword, string? Language);
public sealed record ResetGrant(string ResetToken, DateTime ExpiresAtUtc);

public enum CodeRequestStatus { Accepted, InvalidEmail, Cooldown, Unavailable, Busy, AlreadyVerified }
public sealed record CodeRequestResult(CodeRequestStatus Status, int Seconds = 0);
public enum CodeCheckStatus { Ok, Invalid, Expired, TooManyAttempts, Unavailable }

public static class AccountEmailRegistration
{
    public const string Capability = "account.security", DeliveryCapability = "account.email";

    public static IServiceCollection AddAccountEmail(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        var o = config.GetSection("Email").Get<EmailOptions>() ?? new();
        switch (o.Provider)
        {
            case "":
                break;
            case EmailOptions.Capture when !(env.IsDevelopment() || env.IsEnvironment("Testing")):
                throw new InvalidOperationException("Email:Provider=Capture keeps mail in memory instead of sending it and is refused outside Development/Testing.");
            case EmailOptions.Capture:
                if (o.CodeSecret.Length < 32) o.CodeSecret = AuthService.NewSecret(); // local only: codes die with the process
                break;
            case EmailOptions.Resend:
                if (string.IsNullOrWhiteSpace(o.ResendApiKey) || !MailAddress.TryCreate(o.FromAddress, out _) || o.CodeSecret.Length < 32
                    || (o.ReplyTo.Length > 0 && !MailAddress.TryCreate(o.ReplyTo, out _)))
                    throw new InvalidOperationException("Email:Provider=Resend needs Email:ResendApiKey, a valid Email:FromAddress and Email:CodeSecret (32+ characters). See docs/AUTHENTICATION_EMAIL.md.");
                break;
            default:
                throw new InvalidOperationException("Email:Provider must be empty, Resend or Capture.");
        }
        services.AddSingleton(o);
        services.TryAddSingleton(TimeProvider.System);
        services.AddScoped<AccountEmailService>();
        if (o.Provider == EmailOptions.Resend)
        {
            services.AddHttpClient<ResendSender>(c =>
            {
                c.BaseAddress = new Uri(o.ResendBaseUrl.EndsWith('/') ? o.ResendBaseUrl : o.ResendBaseUrl + "/");
                c.Timeout = TimeSpan.FromSeconds(o.SendTimeoutSeconds + 5); // backstop behind the worker's own bound
            });
            services.AddSingleton<IMailSender>(sp => sp.GetRequiredService<ResendSender>());
        }
        if (o.Provider == EmailOptions.Capture)
        {
            services.AddSingleton<CaptureMailbox>();
            services.AddSingleton<IMailSender>(sp => sp.GetRequiredService<CaptureMailbox>());
        }
        if (o.Configured)
        {
            services.AddSingleton<MailWorker>();
            if (o.WorkerEnabled) services.AddHostedService(sp => sp.GetRequiredService<MailWorker>());
        }
        return services;
    }
}

/// <summary>
/// Emailed codes for password reset and email verification, and the password changes they lead to
/// (docs/AUTHENTICATION_EMAIL.md). Requests only queue mail; <see cref="MailWorker"/> sends it.
/// </summary>
public sealed class AccountEmailService(GoHardDb db, EmailOptions options, TimeProvider time, ILogger<AccountEmailService> log)
{
    public const string Reset = "password-reset", Verify = "email-verification", Changed = "password-changed";
    /// <summary>A live code with less time left than this is replaced rather than sent again.</summary>
    private static readonly TimeSpan MinRemaining = TimeSpan.FromMinutes(2);
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>The 8-digit code of a challenge: HMAC-SHA256 under the server-only secret, never stored. Leading zeros kept.</summary>
    public static string CodeFor(string secret, Guid challengeId)
    {
        var mac = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes("gohard.code|" + challengeId.ToString("N")));
        return (BinaryPrimitives.ReadUInt64BigEndian(mac) % 100_000_000UL).ToString("D8", CultureInfo.InvariantCulture);
    }

    /// <summary>A keyed hash of the normalized address, so challenges for unknown addresses store no address.</summary>
    public string EmailKey(string normalizedEmail) => Convert.ToHexStringLower(
        HMACSHA256.HashData(Encoding.UTF8.GetBytes(options.CodeSecret), Encoding.UTF8.GetBytes("gohard.email|" + normalizedEmail)));

    /// <summary>Digits in any script (Arabic-Indic, Eastern Arabic…) become ASCII; spaces and dashes are dropped.
    /// Anything else, or not exactly 8 digits, is null.</summary>
    public static string? NormalizeCode(string? code)
    {
        var sb = new StringBuilder(8);
        foreach (var ch in code ?? "")
        {
            if (ch is ' ' or '-' or '\u00A0' or '\u2066' or '\u2069') continue;
            var d = CharUnicodeInfo.GetDecimalDigitValue(ch);
            if (d < 0) return null;
            sb.Append((char)('0' + d));
        }
        return sb.Length == 8 ? sb.ToString() : null;
    }

    /// <summary>en, fr or ar for an email; anything else (or nothing, from an older app) is English.</summary>
    public static string MailLanguage(string? language) => (language ?? "").Trim().ToLowerInvariant() switch
    {
        var l when l.StartsWith("fr") => "fr",
        var l when l.StartsWith("ar") => "ar",
        _ => "en",
    };

    public async Task<CodeRequestResult> RequestResetAsync(string? email, string? language, CancellationToken ct)
    {
        if (!options.Configured) return new(CodeRequestStatus.Unavailable);
        var normalized = AuthService.NormalizeEmail(email);
        if (!AuthService.PlausibleEmail(normalized)) return new(CodeRequestStatus.InvalidEmail);
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Email == normalized, ct);
        return await IssueAsync(Reset, normalized, user, language, ct);
    }

    public async Task<CodeRequestResult> RequestVerificationAsync(Guid userId, string? language, CancellationToken ct)
    {
        if (!options.Configured) return new(CodeRequestStatus.Unavailable);
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (user.EmailVerifiedAtUtc is not null) return new(CodeRequestStatus.AlreadyVerified);
        return await IssueAsync(Verify, user.Email, user, language, ct);
    }

    /// <summary>Right after registration: one verification email, only when a sender is configured. A problem here is
    /// logged and never turns the created account into a failed registration.</summary>
    public async Task OfferVerificationAsync(Guid userId, string? language)
    {
        if (!options.Configured) return;
        try { await RequestVerificationAsync(userId, language, CancellationToken.None); }
        catch (Exception ex) when (ex is DbUpdateException or Npgsql.NpgsqlException or InvalidOperationException)
        {
            log.LogWarning("Verification email after registration was not queued ({Error})", ex.GetType().Name);
        }
    }

    /// <summary>
    /// The same steps for a known and an unknown address (the unknown one gets a challenge without an owner and no mail),
    /// so the reply never says whether an account exists. A code that is still live is sent again rather than replaced:
    /// asking again cannot void someone else's code, and its attempt count is kept.
    /// </summary>
    private async Task<CodeRequestResult> IssueAsync(string purpose, string email, User? user, string? language, CancellationToken ct)
    {
        var now = Now;
        var key = EmailKey(email);
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // One request per address and purpose at a time, across every instance: the limits below cannot be raced.
        var lockKey = purpose + "|" + key;
        await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock(hashtextextended({lockKey}, 0))", ct);

        var hourAgo = now.AddHours(-1);
        var recent = await db.AuthChallenges.Where(c => c.EmailKey == key && c.Purpose == purpose && c.CreatedAtUtc > hourAgo).ToListAsync(ct);
        if (recent.MaxBy(c => c.LastSentAtUtc) is { } last && now - last.LastSentAtUtc < TimeSpan.FromSeconds(options.CooldownSeconds))
            return new(CodeRequestStatus.Cooldown, Seconds(last.LastSentAtUtc.AddSeconds(options.CooldownSeconds) - now));
        if (recent.Sum(c => c.SendCount) >= options.MaxSendsPerHour)
            return new(CodeRequestStatus.Cooldown, Seconds(recent.Min(c => c.CreatedAtUtc).AddHours(1) - now));
        // The global budget is checked for every address alike, so "busy" says nothing about any one account.
        if (await db.MailMessages.CountAsync(m => m.CreatedAtUtc > hourAgo, ct) >= options.DeliveryBudgetPerHour)
        {
            log.LogWarning("Email delivery budget of {Budget} per hour reached", options.DeliveryBudgetPerHour);
            return new(CodeRequestStatus.Busy);
        }

        var live = recent.Where(c => c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null && c.VerifiedAtUtc == null
                && c.Attempts < options.MaxAttempts && c.ExpiresAtUtc - now >= MinRemaining && c.SecurityStamp == user?.SecurityStamp)
            .MaxBy(c => c.CreatedAtUtc);
        if (live is null)
        {
            // Only the newest code is accepted. A code already exchanged for a reset authorization keeps that authorization.
            await db.AuthChallenges.Where(c => c.EmailKey == key && c.Purpose == purpose && c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null && c.VerifiedAtUtc == null)
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.InvalidatedAtUtc, now), ct);
            live = new AuthChallenge
            {
                Id = Guid.NewGuid(), UserId = user?.Id, Purpose = purpose, EmailKey = key, SecurityStamp = user?.SecurityStamp,
                CreatedAtUtc = now, ExpiresAtUtc = now.AddMinutes(options.CodeMinutes),
            };
            db.AuthChallenges.Add(live);
        }
        live.SendCount++;
        live.LastSentAtUtc = now;
        if (user is not null) Queue(user.Id, purpose, language, now, live.ExpiresAtUtc, live.Id);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(CodeRequestStatus.Accepted, options.CooldownSeconds);
    }

    private void Queue(Guid userId, string kind, string? language, DateTime now, DateTime expires, Guid? challengeId) =>
        db.MailMessages.Add(new MailMessage
        {
            Id = Guid.NewGuid(), UserId = userId, ChallengeId = challengeId, Kind = kind, Language = MailLanguage(language),
            CreatedAtUtc = now, NextAttemptAtUtc = now, ExpiresAtUtc = expires,
        });

    private static int Seconds(TimeSpan t) => Math.Max(1, (int)Math.Ceiling(t.TotalSeconds));

    /// <summary>
    /// Checks a code against the newest open challenge for the address. The attempt is counted first, by a conditional
    /// update, so concurrent guesses can never exceed the limit. A challenge without an owner never matches.
    /// </summary>
    private async Task<(CodeCheckStatus, AuthChallenge?)> CheckCodeAsync(string purpose, string key, Guid? userId, string? code, CancellationToken ct)
    {
        var now = Now;
        var c = await db.AuthChallenges.AsNoTracking()
            .Where(x => x.EmailKey == key && x.Purpose == purpose && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null && x.VerifiedAtUtc == null)
            .OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
        if (c is null) return (CodeCheckStatus.Invalid, null);
        if (c.ExpiresAtUtc <= now) return (CodeCheckStatus.Expired, null);
        var counted = await db.AuthChallenges.Where(x => x.Id == c.Id && x.Attempts < options.MaxAttempts)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.Attempts, x => x.Attempts + 1), ct);
        if (counted == 0) return (CodeCheckStatus.TooManyAttempts, null);
        var given = NormalizeCode(code);
        var ok = c.UserId is not null && (userId is null || c.UserId == userId) && given is not null
                 && CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(given), Encoding.ASCII.GetBytes(CodeFor(options.CodeSecret, c.Id)));
        if (ok) return (CodeCheckStatus.Ok, c);
        return (c.Attempts + 1 >= options.MaxAttempts ? CodeCheckStatus.TooManyAttempts : CodeCheckStatus.Invalid, null);
    }

    /// <summary>A correct reset code buys one short-lived reset authorization (random; only its hash is kept). It is not a
    /// session and opens nothing but <see cref="CompleteResetAsync"/>.</summary>
    public async Task<(CodeCheckStatus, ResetGrant?)> VerifyResetAsync(string? email, string? code, CancellationToken ct)
    {
        if (!options.Configured) return (CodeCheckStatus.Unavailable, null);
        var (status, c) = await CheckCodeAsync(Reset, EmailKey(AuthService.NormalizeEmail(email)), null, code, ct);
        if (status != CodeCheckStatus.Ok) return (status, null);
        var now = Now;
        var token = AuthService.NewSecret();
        var hash = AuthService.HashToken(token);
        var expires = now.AddMinutes(options.ResetGrantMinutes);
        var won = await db.AuthChallenges.Where(x => x.Id == c!.Id && x.VerifiedAtUtc == null && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.VerifiedAtUtc, now).SetProperty(x => x.GrantHash, hash).SetProperty(x => x.GrantExpiresAtUtc, expires), ct);
        return won == 1 ? (CodeCheckStatus.Ok, new ResetGrant(token, expires)) : (CodeCheckStatus.Invalid, null);
    }

    /// <summary>Spends the reset authorization and sets the new password, in one transaction. Null on success, else an
    /// error code. The password is checked first, so a refused one does not spend the authorization.</summary>
    public async Task<string?> CompleteResetAsync(string? resetToken, string? newPassword, string? language, CancellationToken ct)
    {
        if (!options.Configured) return "EMAIL_UNAVAILABLE";
        if (PasswordPolicy.Check(newPassword) is { } weak) return weak;
        var now = Now;
        var hash = AuthService.HashToken(resetToken ?? "");
        var c = await db.AuthChallenges.AsNoTracking().FirstOrDefaultAsync(x => x.GrantHash == hash && x.Purpose == Reset, ct);
        if (c?.UserId is not { } userId) return "INVALID_RESET_TOKEN";
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var spent = await db.AuthChallenges.Where(x => x.Id == c.Id && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null && x.GrantExpiresAtUtc > now)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAtUtc, now), ct);
        if (spent == 0) return "INVALID_RESET_TOKEN";
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, ct);
        // Bound to the account's address and security version when the code was asked for.
        if (user is null || user.SecurityStamp != c.SecurityStamp || EmailKey(user.Email) != c.EmailKey
            || !await SetPasswordAsync(user, newPassword!, language, now, ct)) return "INVALID_RESET_TOKEN";
        await tx.CommitAsync(ct);
        return null;
    }

    /// <summary>Signed in: the current password is checked on the server. Null on success, else an error code.</summary>
    public async Task<string?> ChangePasswordAsync(Guid userId, string? current, string? next, string? language, CancellationToken ct)
    {
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (!AuthService.VerifyPassword(user, current)) return "WRONG_PASSWORD";
        if (PasswordPolicy.Check(next) is { } weak) return weak;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        if (!await SetPasswordAsync(user, next!, language, Now, ct)) return "WRONG_PASSWORD"; // changed meanwhile by another request
        await tx.CommitAsync(ct);
        return null;
    }

    /// <summary>
    /// The one way a password changes (reset and change). Conditional on the security stamp the caller read, so two
    /// changes cannot both win. Then: a new stamp (every access token fails validation), every refresh token revoked (so
    /// refresh recovery has nothing left to recover), every open code voided, their unsent mail cancelled, and a
    /// password-changed notice queued.
    /// </summary>
    private async Task<bool> SetPasswordAsync(User user, string password, string? language, DateTime now, CancellationToken ct)
    {
        var hash = AuthService.HashPassword(user, password);
        var stamp = AuthService.NewSecret();
        var updated = await db.Users.Where(u => u.Id == user.Id && u.SecurityStamp == user.SecurityStamp)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.PasswordHash, hash).SetProperty(u => u.SecurityStamp, stamp), ct);
        if (updated == 0) return false;
        await db.RefreshTokens.Where(t => t.UserId == user.Id && t.RevokedAtUtc == null).ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAtUtc, now), ct);
        await db.AuthChallenges.Where(c => c.UserId == user.Id && c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.InvalidatedAtUtc, now), ct);
        await db.MailMessages.Where(m => m.UserId == user.Id && m.State == "pending" && m.ChallengeId != null)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.State, "cancelled"), ct);
        if (options.Configured)
        {
            Queue(user.Id, Changed, language, now, now.AddDays(1), null);
            await db.SaveChangesAsync(ct);
        }
        return true;
    }

    /// <summary>Marks the account's current address verified. Changes nothing else: no password, session or address.</summary>
    public async Task<(CodeCheckStatus, ProfileDto?)> ConfirmVerificationAsync(Guid userId, string? code, CancellationToken ct)
    {
        if (!options.Configured) return (CodeCheckStatus.Unavailable, null);
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (user.EmailVerifiedAtUtc is not null) return (CodeCheckStatus.Ok, AuthService.ToProfile(user));
        var (status, c) = await CheckCodeAsync(Verify, EmailKey(user.Email), userId, code, ct);
        if (status != CodeCheckStatus.Ok) return (status, null);
        var now = Now;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var spent = await db.AuthChallenges.Where(x => x.Id == c!.Id && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAtUtc, now), ct);
        if (spent == 0) return (CodeCheckStatus.Invalid, null);
        await db.Users.Where(u => u.Id == userId && u.Email == user.Email).ExecuteUpdateAsync(s => s.SetProperty(u => u.EmailVerifiedAtUtc, now), ct);
        await tx.CommitAsync(ct);
        user.EmailVerifiedAtUtc = now;
        return (CodeCheckStatus.Ok, AuthService.ToProfile(user));
    }
}
