import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The Google Maps key from Secrets.xcconfig (via Info.plist GMSApiKey), or nil in a build without one. The Maps SDK
  /// aborts the app when a map is created without a key, so without one the app never creates a map and draws the
  /// route itself (docs/RUN_WALK.md › Map).
  private var mapsKey: String? {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
          !key.isEmpty, !key.hasPrefix("$(") else { return nil }
    return key
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = mapsKey { GMSServices.provideAPIKey(key) }
    // Lets workout reminders appear while the app is open (flutter_local_notifications).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GoHardMaps") {
      let configured = mapsKey != nil
      FlutterMethodChannel(name: "gohard/maps", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { _, result in result(configured) }
    }
  }
}
