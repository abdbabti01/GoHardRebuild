/// Explicit development configuration. There is deliberately no default API address:
/// a build without `--dart-define=GOHARD_API_BASE=...` shows a configuration error instead of
/// silently talking to some other server.
class AppConfig {
  static const apiBase = String.fromEnvironment('GOHARD_API_BASE');
  static const contractVersion = 1;

  /// Which build this is, stamped by the iOS workflow (commit and workflow run number); 'dev' for a local build.
  static const commit = String.fromEnvironment('GOHARD_COMMIT', defaultValue: 'dev');
  static const build = String.fromEnvironment('GOHARD_BUILD');

  static String? get problem {
    if (apiBase.isEmpty) return 'GOHARD_API_BASE is not set. Launch with scripts\run-android.ps1.';
    final uri = Uri.tryParse(apiBase);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'GOHARD_API_BASE is not a valid URL.';
    return null;
  }
}

/// Capabilities this build has NOT verified end to end stay off. Each is gated individually.
class Capabilities {
  static const routeMaps = false; // GPS measures distance only; no route is stored or drawn
  static const social = false;
  static const healthSync = false;
  static const music = false;
  static const aiAssistance = false; // server adapter exists; no provider is configured
}
