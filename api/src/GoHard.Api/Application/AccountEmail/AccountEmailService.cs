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
    /// <summary>The address the "your email was changed" notice gives for "this wasn't me". The owner chooses a monitored
    /// inbox; none is assumed. Without it, change email is not offered except with local capture (docs › 12).</summary>
    public string SupportAddress { get; set; } = "";
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
    /// <summary>Email verification uses 4-digit codes, so on top of the per-code attempts it has a rolling 24-hour budget
    /// per address: guesses across all its codes, and codes sent. Reaching either stops new codes until it frees up.</summary>
    public int VerifyMaxAttemptsPerDay { get; set; } = 10;
    public int VerifyMaxSendsPerDay { get; set; } = 10;
    public int SendTimeoutSeconds { get; set; } = 15;
    /// <summary>Tests turn the background loop off and run passes themselves.</summary>
    public bool WorkerEnabled { get; set; } = true;
    public bool Configured => Provider is Resend or Capture;
    /// <summary>Change email sends a security notice that must name a real support address, so it is offered only once one
    /// is set (local capture, which sends nothing, works without).</summary>
    public bool EmailChangeOffered => Configured && (Provider == Capture || SupportAddress.Length > 0);
}

public sealed record CodeRequest(string? Email, string? Language);
/// <summary>[CodeDigits] 4 opts a verification request into a 4-digit code; absent or anything else is 8.</summary>
public sealed record LanguageRequest(string? Language, int? CodeDigits = null);
public sealed record CodeVerifyRequest(string? Email, string? Code);
public sealed record CodeConfirmRequest(string? Code);
public sealed record ResetCompleteRequest(string? ResetToken, string? NewPassword, string? Language);
public sealed record PasswordChangeRequest(string? CurrentPassword, string? NewPassword, string? Language);
public sealed record ResetGrant(string ResetToken, DateTime ExpiresAtUtc);
/// <summary>Change email: the new address and the current password. [CodeDigits] 4 opts into a 4-digit code.</summary>
public sealed record EmailChangeRequest(string? NewEmail, string? CurrentPassword, string? Language, int? CodeDigits = null);
public sealed record EmailChangeConfirmRequest(string? Code, string? Language);

public enum CodeRequestStatus { Accepted, InvalidEmail, Cooldown, Unavailable, Busy, AlreadyVerified, WrongPassword, SameEmail, EmailInUse, NoPendingChange }
public sealed record CodeRequestResult(CodeRequestStatus Status, int Seconds = 0);
public enum CodeCheckStatus { Ok, Invalid, Expired, TooManyAttempts, Unavailable, EmailInUse }

public static class AccountEmailRegistration
{
    public const string Capability = "account.security", DeliveryCapability = "account.email", ChangeCapability = "account.email-change";

    public static IServiceCollection AddAccountEmail(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        var o = config.GetSection("Email").Get<EmailOptions>() ?? new();
        o.SupportAddress = o.SupportAddress.Trim();
        if (o.SupportAddress.Length > 0 && !MailAddress.TryCreate(o.SupportAddress, out _))
            throw new InvalidOperationException("Email:SupportAddress must be a valid email address (or empty: change email is then not offered).");
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
public sealed class AccountEmailService(GoHardDb db, EmailOptions options, TimeProvider time, AccountAccess access, ILogger<AccountEmailService> log)
{
    public const string Reset = "password-reset", Verify = "email-verification", Changed = "password-changed";
    /// <summary>Change email: the code sent to the proposed address, and the notice sent to the old one once it changed.</summary>
    public const string EmailChange = "email-change", EmailChanged = "email-changed";
    /// <summary>Purposes with short codes and a per-address daily budget of guesses and sends.</summary>
    private static bool ShortCodes(string purpose) => purpose is Verify or EmailChange;
    /// <summary>A live code with less time left than this is replaced rather than sent again.</summary>
    private static readonly TimeSpan MinRemaining = TimeSpan.FromMinutes(2);
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>Code lengths: 8 (password reset always, verification by default) or 4 (verification, when the requesting
    /// app opts in). Each challenge keeps its own length; a code is accepted only in exactly that length.</summary>
    public const int VerifyDigits = 4, ResetDigits = 8;
    public static int RequestedDigits(int? codeDigits) => codeDigits == VerifyDigits ? VerifyDigits : ResetDigits;

    /// <summary>The code of a challenge: HMAC-SHA256 under the server-only secret over its random ID, never stored, so it
    /// is uniform over every value of that length (leading zeros kept).</summary>
    public static string CodeFor(string secret, Guid challengeId, int digits = ResetDigits)
    {
        var mac = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes("gohard.code|" + challengeId.ToString("N")));
        var mod = digits == VerifyDigits ? 10_000UL : 100_000_000UL;
        return (BinaryPrimitives.ReadUInt64BigEndian(mac) % mod).ToString("D" + digits, CultureInfo.InvariantCulture);
    }

    /// <summary>A keyed hash of the normalized address, so challenges for unknown addresses store no address.</summary>
    public string EmailKey(string normalizedEmail) => Convert.ToHexStringLower(
        HMACSHA256.HashData(Encoding.UTF8.GetBytes(options.CodeSecret), Encoding.UTF8.GetBytes("gohard.email|" + normalizedEmail)));

    /// <summary>Digits in any script (Arabic-Indic, Eastern Arabic…) become ASCII; spaces and dashes are dropped.
    /// Anything else, or not exactly 4 or 8 digits, is null (the caller compares with the code of its own length).</summary>
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
        return sb.Length is VerifyDigits or ResetDigits ? sb.ToString() : null;
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

    public async Task<CodeRequestResult> RequestVerificationAsync(Guid userId, string? language, CancellationToken ct, int? codeDigits = null)
    {
        if (!options.Configured) return new(CodeRequestStatus.Unavailable);
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (user.EmailVerifiedAtUtc is not null) return new(CodeRequestStatus.AlreadyVerified);
        return await IssueAsync(Verify, user.Email, user, language, ct, RequestedDigits(codeDigits));
    }

    /// <summary>Right after registration: one verification email, only when a sender is configured. A problem here is
    /// logged and never turns the created account into a failed registration.</summary>
    public async Task OfferVerificationAsync(Guid userId, string? language, int? codeDigits = null)
    {
        if (!options.Configured) return;
        try { await RequestVerificationAsync(userId, language, CancellationToken.None, codeDigits); }
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
    private async Task<CodeRequestResult> IssueAsync(string purpose, string email, User? user, string? language, CancellationToken ct, int digits = ResetDigits)
    {
        var now = Now;
        var key = EmailKey(email);
        var change = purpose == EmailChange;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // An email change is also one request per account at a time (taken first, always in this order), so asking for two
        // addresses at once cannot leave two live codes.
        if (change)
        {
            var userLock = EmailChange + "|user|" + user!.Id.ToString("N");
            await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock(hashtextextended({userLock}, 0))", ct);
        }
        // One request per address and purpose at a time, across every instance: the limits below cannot be raced.
        var lockKey = purpose + "|" + key;
        await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock(hashtextextended({lockKey}, 0))", ct);

        var hourAgo = now.AddHours(-1);
        var recent = await db.AuthChallenges.Where(c => c.EmailKey == key && c.Purpose == purpose && c.CreatedAtUtc > hourAgo).ToListAsync(ct);
        if (recent.MaxBy(c => c.LastSentAtUtc) is { } last && now - last.LastSentAtUtc < TimeSpan.FromSeconds(options.CooldownSeconds))
            return new(CodeRequestStatus.Cooldown, Seconds(last.LastSentAtUtc.AddSeconds(options.CooldownSeconds) - now));
        if (recent.Sum(c => c.SendCount) >= options.MaxSendsPerHour)
            return new(CodeRequestStatus.Cooldown, Seconds(recent.Min(c => c.CreatedAtUtc).AddHours(1) - now));
        // Verification (short codes): no new code once the day's guesses or sends are used up, so resending can never
        // buy unlimited guesses or unlimited mail.
        if (ShortCodes(purpose))
        {
            var dayAgo = now.AddDays(-1);
            var day = await db.AuthChallenges.Where(c => c.EmailKey == key && c.Purpose == purpose && c.CreatedAtUtc > dayAgo).ToListAsync(ct);
            // An email change also has the same budget per account, across every address it tries.
            if (change) day = [.. day.UnionBy(await db.AuthChallenges.Where(c => c.UserId == user!.Id && c.Purpose == purpose && c.CreatedAtUtc > dayAgo).ToListAsync(ct), c => c.Id)];
            if (day.Count > 0 && (day.Sum(c => c.Attempts) >= options.VerifyMaxAttemptsPerDay || day.Sum(c => c.SendCount) >= options.VerifyMaxSendsPerDay))
                return new(CodeRequestStatus.Cooldown, Seconds(day.Min(c => c.CreatedAtUtc).AddDays(1) - now));
        }
        // The global budget is checked for every address alike, so "busy" says nothing about any one account.
        if (await db.MailMessages.CountAsync(m => m.CreatedAtUtc > hourAgo, ct) >= options.DeliveryBudgetPerHour)
        {
            log.LogWarning("Email delivery budget of {Budget} per hour reached", options.DeliveryBudgetPerHour);
            return new(CodeRequestStatus.Busy);
        }

        var live = recent.Where(c => c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null && c.VerifiedAtUtc == null
                && c.Attempts < options.MaxAttempts && c.ExpiresAtUtc - now >= MinRemaining && c.SecurityStamp == user?.SecurityStamp
                // Re-sent only in the length asked for: an app that can enter only 8 digits gets a new 8-digit code.
                && c.CodeDigits == digits
                // An email change's code belongs to one account and one proposed address.
                && (!change || (c.UserId == user!.Id && c.NewEmail == email)))
            .MaxBy(c => c.CreatedAtUtc);
        if (live is null)
        {
            // Only the newest code is accepted. A code already exchanged for a reset authorization keeps that authorization.
            // An email change replaces the account's earlier request, whatever address it was for (another account's
            // request for the same address is not this account's to void).
            var open = db.AuthChallenges.Where(c => c.Purpose == purpose && c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null && c.VerifiedAtUtc == null);
            await (change ? open.Where(c => c.UserId == user!.Id) : open.Where(c => c.EmailKey == key))
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.InvalidatedAtUtc, now), ct);
            live = new AuthChallenge
            {
                Id = Guid.NewGuid(), UserId = user?.Id, Purpose = purpose, EmailKey = key, SecurityStamp = user?.SecurityStamp,
                CreatedAtUtc = now, ExpiresAtUtc = now.AddMinutes(options.CodeMinutes), CodeDigits = digits, NewEmail = change ? email : null,
            };
            db.AuthChallenges.Add(live);
        }
        live.SendCount++;
        live.LastSentAtUtc = now;
        if (user is not null) Queue(user.Id, purpose, language, now, live.ExpiresAtUtc, live.Id, change ? email : null);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(CodeRequestStatus.Accepted, options.CooldownSeconds);
    }

    private void Queue(Guid userId, string kind, string? language, DateTime now, DateTime expires, Guid? challengeId, string? to = null) =>
        db.MailMessages.Add(new MailMessage
        {
            Id = Guid.NewGuid(), UserId = userId, ChallengeId = challengeId, Kind = kind, Language = MailLanguage(language),
            CreatedAtUtc = now, NextAttemptAtUtc = now, ExpiresAtUtc = expires, ToEmail = to,
        });

    private static int Seconds(TimeSpan t) => Math.Max(1, (int)Math.Ceiling(t.TotalSeconds));

    /// <summary>
    /// Checks a code against the newest open challenge for the address. The attempt is counted first, by a conditional
    /// update, so concurrent guesses can never exceed the limit. A challenge without an owner never matches.
    /// </summary>
    private async Task<(CodeCheckStatus, AuthChallenge?)> CheckCodeAsync(string purpose, string key, Guid? userId, string? code, CancellationToken ct)
    {
        if (!ShortCodes(purpose)) return await CheckOnceAsync(purpose, key, userId, code, ct);
        // Short codes: the day's guesses across every code of this address (an email change: of this account) are capped
        // too, under a lock so concurrent guesses cannot pass the cap between the count and the attempt.
        var change = purpose == EmailChange;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var lockKey = change ? "email-change-check|" + userId : "verify-check|" + key;
        await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock(hashtextextended({lockKey}, 0))", ct);
        var dayAgo = Now.AddDays(-1);
        var day = db.AuthChallenges.Where(x => x.Purpose == purpose && x.CreatedAtUtc > dayAgo);
        if (await (change ? day.Where(x => x.UserId == userId) : day.Where(x => x.EmailKey == key)).SumAsync(x => x.Attempts, ct) >= options.VerifyMaxAttemptsPerDay)
            return (CodeCheckStatus.TooManyAttempts, null);
        var result = await CheckOnceAsync(purpose, key, userId, code, ct);
        await tx.CommitAsync(ct);
        return result;
    }

    private async Task<(CodeCheckStatus, AuthChallenge?)> CheckOnceAsync(string purpose, string key, Guid? userId, string? code, CancellationToken ct)
    {
        var now = Now;
        var open = db.AuthChallenges.AsNoTracking().Where(x => x.Purpose == purpose && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null && x.VerifiedAtUtc == null);
        // An email change's code is the account's own newest request, never another account's for the same address.
        var c = await (purpose == EmailChange ? open.Where(x => x.UserId == userId) : open.Where(x => x.EmailKey == key))
            .OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
        if (c is null) return (CodeCheckStatus.Invalid, null);
        if (c.ExpiresAtUtc <= now) return (CodeCheckStatus.Expired, null);
        var counted = await db.AuthChallenges.Where(x => x.Id == c.Id && x.Attempts < options.MaxAttempts)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.Attempts, x => x.Attempts + 1), ct);
        if (counted == 0) return (CodeCheckStatus.TooManyAttempts, null);
        var given = NormalizeCode(code);
        // Exactly the challenge's own length: an 8-digit code needs all 8 digits (codes from before 4-digit codes are 8).
        var ok = c.UserId is not null && (userId is null || c.UserId == userId) && given is not null && given.Length == c.CodeDigits
                 && CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(given), Encoding.ASCII.GetBytes(CodeFor(options.CodeSecret, c.Id, c.CodeDigits)));
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
        if (user.EmailVerifiedAtUtc is not null) return (CodeCheckStatus.Ok, access.Profile(user));
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
        return (CodeCheckStatus.Ok, access.Profile(user));
    }

    // ---------------------------------------------------------------- change email (docs/AUTHENTICATION_EMAIL.md › 12)

    /// <summary>
    /// Signed in, with the current password: sends a code to [newEmail]. Nothing about the account changes until the code
    /// is confirmed: the current address keeps signing in and receiving password-reset codes. A request for another address
    /// replaces this account's earlier one (its code stops working).
    /// </summary>
    public async Task<CodeRequestResult> RequestEmailChangeAsync(Guid userId, string? newEmail, string? currentPassword, string? language, int? codeDigits, CancellationToken ct)
    {
        if (!options.EmailChangeOffered) return new(CodeRequestStatus.Unavailable);
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (!AuthService.VerifyPassword(user, currentPassword)) return new(CodeRequestStatus.WrongPassword);
        var normalized = AuthService.NormalizeEmail(newEmail);
        if (!AuthService.PlausibleEmail(normalized)) return new(CodeRequestStatus.InvalidEmail);
        if (normalized == user.Email) return new(CodeRequestStatus.SameEmail);
        // Said as registration says it (EMAIL_IN_USE); checked again when the change is committed.
        if (await db.Users.AnyAsync(u => u.Email == normalized && u.Id != userId, ct)) return new(CodeRequestStatus.EmailInUse);
        return await IssueAsync(EmailChange, normalized, user, language, ct, RequestedDigits(codeDigits));
    }

    /// <summary>The account's open request, if any (newest, not confirmed, cancelled or replaced, at most a day old).</summary>
    private Task<AuthChallenge?> PendingChangeAsync(Guid userId, CancellationToken ct)
    {
        var dayAgo = Now.AddDays(-1);
        return db.AuthChallenges.AsNoTracking()
            .Where(c => c.UserId == userId && c.Purpose == EmailChange && c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null && c.CreatedAtUtc > dayAgo)
            .OrderByDescending(c => c.CreatedAtUtc).FirstOrDefaultAsync(ct);
    }

    /// <summary>Resend: the open request's code again (or a new one when it expired or was locked), to the same address.
    /// The password was checked when the request was made; a password change since then voided the request.</summary>
    public async Task<CodeRequestResult> ResendEmailChangeAsync(Guid userId, string? language, int? codeDigits, CancellationToken ct)
    {
        if (!options.EmailChangeOffered) return new(CodeRequestStatus.Unavailable);
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (await PendingChangeAsync(userId, ct) is not { NewEmail: { } to } pending || pending.SecurityStamp != user.SecurityStamp)
            return new(CodeRequestStatus.NoPendingChange);
        if (await db.Users.AnyAsync(u => u.Email == to && u.Id != userId, ct)) return new(CodeRequestStatus.EmailInUse);
        return await IssueAsync(EmailChange, to, user, language, ct, RequestedDigits(codeDigits));
    }

    /// <summary>Cancel: the open request's code stops working and its unsent mail is not sent. Nothing else changes.</summary>
    public async Task CancelEmailChangeAsync(Guid userId, CancellationToken ct)
    {
        var now = Now;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var open = db.AuthChallenges.Where(c => c.UserId == userId && c.Purpose == EmailChange && c.ConsumedAtUtc == null && c.InvalidatedAtUtc == null);
        await db.MailMessages.Where(m => m.State == "pending" && open.Any(c => c.Id == m.ChallengeId)).ExecuteUpdateAsync(s => s.SetProperty(m => m.State, "cancelled"), ct);
        await open.ExecuteUpdateAsync(s => s.SetProperty(c => c.InvalidatedAtUtc, now), ct);
        await tx.CommitAsync(ct);
    }

    /// <summary>
    /// The code from the new address commits the change, in one transaction: the address is checked to be free again
    /// (and the unique index decides a race), the account keeps its ID and everything it owns, the new address becomes its
    /// sign-in and recovery address (verified: the code proved it), every session ends as for a password change, every
    /// other open code is voided, and a notice goes to the old address.
    /// </summary>
    public async Task<CodeCheckStatus> ConfirmEmailChangeAsync(Guid userId, string? code, string? language, CancellationToken ct)
    {
        if (!options.EmailChangeOffered) return CodeCheckStatus.Unavailable;
        var (status, c) = await CheckCodeAsync(EmailChange, "", userId, code, ct);
        if (status != CodeCheckStatus.Ok) return status;
        var user = await db.Users.AsNoTracking().FirstAsync(u => u.Id == userId, ct);
        if (c!.NewEmail is not { } to || c.SecurityStamp != user.SecurityStamp) return CodeCheckStatus.Invalid;
        var now = Now;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var addressLock = EmailChange + "|commit|" + EmailKey(to);
        await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock(hashtextextended({addressLock}, 0))", ct);
        if (await db.Users.AnyAsync(u => u.Email == to && u.Id != userId, ct))
        {
            await db.AuthChallenges.Where(x => x.Id == c.Id).ExecuteUpdateAsync(s => s.SetProperty(x => x.InvalidatedAtUtc, now), ct);
            await tx.CommitAsync(ct);
            return CodeCheckStatus.EmailInUse;
        }
        var spent = await db.AuthChallenges.Where(x => x.Id == c.Id && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAtUtc, now), ct);
        if (spent == 0) return CodeCheckStatus.Invalid;
        var stamp = AuthService.NewSecret();
        int updated;
        try
        {
            // Conditional on what was read: a password change or another email change in between wins, this one does not.
            updated = await db.Users.Where(u => u.Id == userId && u.SecurityStamp == user.SecurityStamp && u.Email == user.Email)
                .ExecuteUpdateAsync(s => s.SetProperty(u => u.Email, to).SetProperty(u => u.EmailVerifiedAtUtc, now).SetProperty(u => u.SecurityStamp, stamp), ct);
        }
        catch (Npgsql.PostgresException e) when (e.SqlState == Npgsql.PostgresErrorCodes.UniqueViolation)
        {
            return CodeCheckStatus.EmailInUse; // another account took it (registration) after the check: nothing changed
        }
        if (updated == 0) return CodeCheckStatus.Invalid;
        await db.RefreshTokens.Where(t => t.UserId == userId && t.RevokedAtUtc == null).ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAtUtc, now), ct);
        await db.AuthChallenges.Where(x => x.UserId == userId && x.ConsumedAtUtc == null && x.InvalidatedAtUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.InvalidatedAtUtc, now), ct);
        await db.MailMessages.Where(m => m.UserId == userId && m.State == "pending" && m.ChallengeId != null)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.State, "cancelled"), ct);
        Queue(userId, EmailChanged, language, now, now.AddDays(1), null, user.Email);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        log.LogInformation("Account email changed ({UserId})", userId);
        return CodeCheckStatus.Ok;
    }
}
