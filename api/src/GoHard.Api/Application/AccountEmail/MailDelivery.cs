using System.Net;
using System.Net.Http.Headers;
using MailAddress = System.Net.Mail.MailAddress;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application.AccountEmail;

public sealed record OutgoingMail(string To, string Subject, string Text, string Html);
public enum SendOutcome { Sent, Retry, Failed }
public sealed record SendResult(SendOutcome Outcome, string? ProviderId = null, string? Error = null);

/// <summary>One transport. Production: <see cref="ResendSender"/>. Development/Testing only: <see cref="CaptureMailbox"/>.</summary>
public interface IMailSender
{
    /// <summary>The same <paramref name="idempotencyKey"/> is given for every retry of one message, with the same content.</summary>
    Task<SendResult> SendAsync(OutgoingMail mail, string idempotencyKey, CancellationToken ct);
}

/// <summary>
/// HTTP only, for Resend's Send Email API. Docs relied on (read 21 Oct 2026):
/// - https://resend.com/docs/api-reference/emails/send-email : POST https://api.resend.com/emails, Authorization: Bearer
///   key; from (with display name), to, subject, html, text, reply_to; answer {"id"}.
/// - https://resend.com/docs/dashboard/emails/idempotency-keys : Idempotency-Key header, 1–256 characters, kept 24 h; the
///   same key and payload returns the original answer without sending again; same key with another payload is 409
///   invalid_idempotent_request; a concurrent request with the key is 409 concurrent_idempotent_requests (retry later).
/// - https://resend.com/docs/dashboard/domains/introduction : open/click tracking is a per-domain setting (there is no
///   per-message switch); the sending domain must keep it off (docs/AUTHENTICATION_EMAIL.md).
/// The key is never logged; only the status and Resend's error name are.
/// </summary>
public sealed class ResendSender(HttpClient http, EmailOptions options) : IMailSender
{
    public async Task<SendResult> SendAsync(OutgoingMail mail, string idempotencyKey, CancellationToken ct)
    {
        var body = new JsonObject
        {
            ["from"] = new MailAddress(options.FromAddress, options.FromName).ToString(),
            ["to"] = new JsonArray(mail.To),
            ["subject"] = mail.Subject,
            ["html"] = mail.Html,
            ["text"] = mail.Text,
        };
        if (!string.IsNullOrWhiteSpace(options.ReplyTo)) body["reply_to"] = options.ReplyTo.Trim();
        using var request = new HttpRequestMessage(HttpMethod.Post, "emails") { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.ResendApiKey.Trim());
        request.Headers.Add("Idempotency-Key", idempotencyKey);
        using var response = await http.SendAsync(request, ct);
        var text = await response.Content.ReadAsStringAsync(ct);
        string? Field(string name)
        {
            try { return JsonNode.Parse(text)?[name]?.GetValue<string>(); }
            catch (Exception e) when (e is JsonException or InvalidOperationException) { return null; }
        }
        if (response.IsSuccessStatusCode) return new(SendOutcome.Sent, Field("id"));
        var status = (int)response.StatusCode;
        var error = $"{status} {Field("name")}".Trim();
        // Rate limits, server trouble and an in-flight duplicate are worth another try with the same key; anything else
        // (bad key, unverified domain, invalid request, another payload under this key) will not get better by retrying.
        var retry = status is 429 or >= 500 || (status == 409 && Field("name") == "concurrent_idempotent_requests");
        return new(retry ? SendOutcome.Retry : SendOutcome.Failed, Error: error);
    }
}

public sealed record CapturedMail(string To, string Subject, string Text, string Html, string IdempotencyKey);

/// <summary>Development/Testing only (refused elsewhere at startup): keeps messages in memory instead of sending them,
/// one per idempotency key like a provider would. Nothing here is real delivery.</summary>
public sealed class CaptureMailbox : IMailSender
{
    private readonly List<CapturedMail> _mail = [];

    public Task<SendResult> SendAsync(OutgoingMail mail, string idempotencyKey, CancellationToken ct)
    {
        lock (_mail)
        {
            if (!_mail.Any(m => m.IdempotencyKey == idempotencyKey)) _mail.Add(new(mail.To, mail.Subject, mail.Text, mail.Html, idempotencyKey));
            if (_mail.Count > 500) _mail.RemoveAt(0);
        }
        return Task.FromResult(new SendResult(SendOutcome.Sent, "capture-" + idempotencyKey));
    }

    public IReadOnlyList<CapturedMail> All { get { lock (_mail) return _mail.ToList(); } }
    public CapturedMail? Latest(string to) { lock (_mail) return _mail.LastOrDefault(m => string.Equals(m.To, to, StringComparison.OrdinalIgnoreCase)); }
}

/// <summary>
/// Sends the outbox. Each pass claims due rows with FOR UPDATE SKIP LOCKED and pushes them past a lease, so several
/// instances never send one row at once and a crash mid-send is picked up after the lease. Before sending it re-checks
/// that the code is still live; it never sends a used, voided or expired code, and stops at the message's expiry.
/// Every attempt for a row uses the same idempotency key and the same content (the code is re-derived, never stored).
/// </summary>
public sealed class MailWorker(IServiceScopeFactory scopes, IMailSender sender, EmailOptions options, TimeProvider time, ILogger<MailWorker> log) : BackgroundService
{
    private DateTime _purgedAt;

    protected override async Task ExecuteAsync(CancellationToken stop)
    {
        while (!stop.IsCancellationRequested)
        {
            try
            {
                if (await RunOnceAsync(stop) == 0) await Task.Delay(TimeSpan.FromSeconds(2), stop);
            }
            catch (OperationCanceledException) when (stop.IsCancellationRequested) { break; }
            catch (Exception ex)
            {
                // For example the schema is not migrated yet. Only the exception type: never a recipient or content.
                log.LogWarning("Mail delivery pass failed ({Error})", ex.GetType().Name);
                try { await Task.Delay(TimeSpan.FromSeconds(15), stop); } catch (OperationCanceledException) { break; }
            }
        }
    }

    /// <summary>One pass: claims up to 10 due messages and makes one attempt at each. Returns how many it claimed.</summary>
    public async Task<int> RunOnceAsync(CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<GoHardDb>();
        var now = time.GetUtcNow().UtcDateTime;
        var lease = now.AddSeconds(options.SendTimeoutSeconds * 2 + 30);
        var ids = await db.Database.SqlQuery<Guid>($"""
            UPDATE "MailMessages" SET "NextAttemptAtUtc" = {lease}, "Attempts" = "Attempts" + 1
            WHERE "Id" IN (SELECT "Id" FROM "MailMessages" WHERE "State" = 'pending' AND "NextAttemptAtUtc" <= {now}
                           ORDER BY "NextAttemptAtUtc" LIMIT 10 FOR UPDATE SKIP LOCKED)
            RETURNING "Id" AS "Value"
            """).ToListAsync(ct);
        foreach (var id in ids) await DeliverAsync(db, id, now, ct);
        if (ids.Count == 0 && now - _purgedAt > TimeSpan.FromMinutes(10)) await PurgeAsync(db, now, ct);
        return ids.Count;
    }

    private async Task DeliverAsync(GoHardDb db, Guid id, DateTime now, CancellationToken ct)
    {
        var m = await db.MailMessages.FirstOrDefaultAsync(x => x.Id == id, ct);
        if (m is null) return; // the account was erased meanwhile
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == m.UserId, ct);
        var c = m.ChallengeId is { } cid ? await db.AuthChallenges.AsNoTracking().FirstOrDefaultAsync(x => x.Id == cid, ct) : null;
        var stop = m.ExpiresAtUtc <= now ? "expired"
            : user is null || (m.ChallengeId is not null && (c is null || c.ConsumedAtUtc != null || c.InvalidatedAtUtc != null || c.VerifiedAtUtc != null || c.ExpiresAtUtc <= now))
                ? "cancelled" : null;
        if (stop is not null)
        {
            m.State = stop;
            await db.SaveChangesAsync(ct);
            log.LogInformation("Mail {Id} ({Kind}) {State} before sending", m.Id, m.Kind, stop);
            return;
        }

        // Minutes as of when the message was queued: fixed per message, so every retry carries identical content.
        var minutes = c is null ? 0 : (int)Math.Ceiling((c.ExpiresAtUtc - m.CreatedAtUtc).TotalMinutes);
        var (subject, text, html) = MailTemplates.Render(m.Kind, m.Language, c is null ? null : AccountEmailService.CodeFor(options.CodeSecret, c.Id), minutes);
        using var bound = CancellationTokenSource.CreateLinkedTokenSource(ct);
        bound.CancelAfter(TimeSpan.FromSeconds(options.SendTimeoutSeconds));
        SendResult result;
        try { result = await sender.SendAsync(new OutgoingMail(user!.Email, subject, text, html), "gohard-mail-" + m.Id.ToString("N"), bound.Token); }
        catch (Exception ex) when (ex is HttpRequestException || (ex is OperationCanceledException && !ct.IsCancellationRequested))
        {
            // No answer: perhaps sent, perhaps not. The retry uses the same key, so the provider sends it at most once.
            result = new(SendOutcome.Retry, Error: ex is OperationCanceledException ? "timeout" : "network");
        }

        switch (result.Outcome)
        {
            case SendOutcome.Sent:
                (m.State, m.SentAtUtc, m.ProviderId, m.LastError) = ("sent", now, result.ProviderId, null);
                break;
            case SendOutcome.Retry when m.Attempts < options.MaxDeliveryAttempts:
                m.LastError = result.Error;
                m.NextAttemptAtUtc = now.AddSeconds(Math.Min(300, 10 << Math.Min(m.Attempts, 5)));
                break;
            default:
                (m.State, m.LastError) = ("failed", result.Error);
                break;
        }
        await db.SaveChangesAsync(CancellationToken.None);
        log.LogInformation("Mail {Id} ({Kind}) attempt {Attempt}: {Outcome} {Error}", m.Id, m.Kind, m.Attempts, result.Outcome, result.Error);
    }

    /// <summary>Codes and finished mail do not linger: a day after expiry, and a week after a message ended.</summary>
    private async Task PurgeAsync(GoHardDb db, DateTime now, CancellationToken ct)
    {
        _purgedAt = now;
        var day = now.AddDays(-1);
        await db.MailMessages.Where(m => m.State != "pending" && m.CreatedAtUtc < now.AddDays(-7)).ExecuteDeleteAsync(ct);
        await db.AuthChallenges.Where(c => c.ExpiresAtUtc < day && (c.GrantExpiresAtUtc == null || c.GrantExpiresAtUtc < day)
            && !db.MailMessages.Any(m => m.ChallengeId == c.Id)).ExecuteDeleteAsync(ct);
    }
}

/// <summary>
/// The three messages in English, French and Arabic: plain text and simple HTML, GoHard named, purpose, expiry and an
/// "if you didn't ask" line. No user-supplied text, remote images, links or tracking. Arabic reads right to left; the
/// code stays left to right (an isolate in the text part, dir="ltr" in the HTML).
/// </summary>
public static class MailTemplates
{
    private sealed record Words(string Subject, string[] Before, string[] After);

    private static readonly Dictionary<(string Kind, string Lang), Words> All = new()
    {
        [(AccountEmailService.Reset, "en")] = new("Your GoHard password reset code",
            ["Use this code in the GoHard app to reset your password:"],
            ["It expires in {m} minutes. Never share it: GoHard will never ask you for it.",
             "If you didn't ask to reset your password, ignore this email. Your password has not changed."]),
        [(AccountEmailService.Verify, "en")] = new("Verify your GoHard email",
            ["Enter this code in the GoHard app to confirm that this email address is yours:"],
            ["It expires in {m} minutes.",
             "If you didn't create a GoHard account or ask for this code, ignore this email."]),
        [(AccountEmailService.Changed, "en")] = new("Your GoHard password was changed",
            ["The password of your GoHard account was just changed, and every device was signed out."],
            ["If this was you, there is nothing else to do.",
             "If you didn't change it, reset your password now from the GoHard sign-in screen (Forgot password?)."]),

        [(AccountEmailService.Reset, "fr")] = new("Ton code de réinitialisation GoHard",
            ["Entre ce code dans l'app GoHard pour réinitialiser ton mot de passe :"],
            ["Il expire dans {m} minutes. Ne le partage avec personne : GoHard ne te le demandera jamais.",
             "Si tu n'as pas demandé à réinitialiser ton mot de passe, ignore ce courriel. Ton mot de passe n'a pas changé."]),
        [(AccountEmailService.Verify, "fr")] = new("Confirme ton adresse courriel GoHard",
            ["Entre ce code dans l'app GoHard pour confirmer que cette adresse courriel est bien la tienne :"],
            ["Il expire dans {m} minutes.",
             "Si tu n'as pas créé de compte GoHard ni demandé ce code, ignore ce courriel."]),
        [(AccountEmailService.Changed, "fr")] = new("Ton mot de passe GoHard a été changé",
            ["Le mot de passe de ton compte GoHard vient d'être changé, et tous les appareils ont été déconnectés."],
            ["Si c'est toi, tu n'as rien d'autre à faire.",
             "Sinon, réinitialise ton mot de passe tout de suite depuis l'écran de connexion de GoHard (Mot de passe oublié?)."]),

        [(AccountEmailService.Reset, "ar")] = new("رمز إعادة تعيين كلمة مرور GoHard",
            ["أدخل هذا الرمز في تطبيق GoHard لإعادة تعيين كلمة المرور:"],
            ["تنتهي صلاحيته بعد {m} دقائق. لا تشاركه مع أحد: لن يطلبه منك GoHard أبدًا.",
             "إذا لم تطلب إعادة تعيين كلمة المرور، فتجاهل هذه الرسالة. لم تتغيّر كلمة مرورك."]),
        [(AccountEmailService.Verify, "ar")] = new("تأكيد بريدك الإلكتروني في GoHard",
            ["أدخل هذا الرمز في تطبيق GoHard لتأكيد أن عنوان البريد الإلكتروني هذا يخصّك:"],
            ["تنتهي صلاحيته بعد {m} دقائق.",
             "إذا لم تُنشئ حسابًا في GoHard أو لم تطلب هذا الرمز، فتجاهل هذه الرسالة."]),
        [(AccountEmailService.Changed, "ar")] = new("تم تغيير كلمة مرور GoHard",
            ["تم للتو تغيير كلمة مرور حسابك في GoHard، وتم تسجيل الخروج من جميع الأجهزة."],
            ["إذا كنت أنت من غيّرها، فلا حاجة لفعل أي شيء آخر.",
             "إذا لم تغيّرها أنت، فأعد تعيين كلمة المرور الآن من شاشة تسجيل الدخول في GoHard (نسيت كلمة المرور؟)."]),
    };

    private static readonly Dictionary<string, string> Footer = new()
    {
        ["en"] = "This is an automatic message from GoHard.",
        ["fr"] = "Ce message automatique t'a été envoyé par GoHard.",
        ["ar"] = "هذه رسالة تلقائية من GoHard.",
    };

    public static (string Subject, string Text, string Html) Render(string kind, string language, string? code, int minutes)
    {
        var lang = All.ContainsKey((kind, language)) ? language : "en";
        var w = All[(kind, lang)];
        string Fill(string s) => s.Replace("{m}", minutes.ToString(System.Globalization.CultureInfo.InvariantCulture));
        var rtl = lang == "ar";

        var text = new StringBuilder("GoHard\n\n");
        foreach (var p in w.Before) text.Append(Fill(p)).Append("\n\n");
        if (code is not null) text.Append(rtl ? $"\u2066{code}\u2069" : code).Append("\n\n");
        foreach (var p in w.After) text.Append(Fill(p)).Append("\n\n");
        text.Append("— ").Append(Footer[lang]).Append('\n');

        static string E(string s) => WebUtility.HtmlEncode(s);
        var html = new StringBuilder();
        html.Append($"<!doctype html><html lang=\"{lang}\" dir=\"{(rtl ? "rtl" : "ltr")}\"><head><meta charset=\"utf-8\"><title>{E(w.Subject)}</title></head>");
        html.Append($"<body style=\"margin:0;padding:24px;background:#f6f3ee;color:#1d1b19;font-family:-apple-system,'Segoe UI',Roboto,Arial,sans-serif;font-size:16px;line-height:1.5;text-align:{(rtl ? "right" : "left")}\">");
        html.Append("<div style=\"max-width:520px;margin:0 auto;background:#ffffff;border-radius:16px;padding:28px\">");
        html.Append("<p dir=\"ltr\" style=\"margin:0 0 20px;font-family:Georgia,serif;font-size:26px;color:#1f4e8c\">GoHard</p>");
        foreach (var p in w.Before) html.Append($"<p style=\"margin:0 0 16px\">{E(Fill(p))}</p>");
        if (code is not null)
            html.Append($"<p dir=\"ltr\" style=\"margin:8px 0 24px;text-align:center;font-family:Menlo,Consolas,monospace;font-size:32px;letter-spacing:6px;font-weight:bold\">{E(code)}</p>");
        foreach (var p in w.After) html.Append($"<p style=\"margin:0 0 16px\">{E(Fill(p))}</p>");
        html.Append($"<p style=\"margin:24px 0 0;font-size:13px;color:#6b645c\">{E(Footer[lang])}</p></div></body></html>");
        return (w.Subject, text.ToString(), html.ToString());
    }
}
