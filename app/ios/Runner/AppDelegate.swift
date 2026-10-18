import AudioToolbox
import CoreMotion
import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Kept for the app's lifetime: the steps channel's handler and its pedometer.
  private var steps: StepsBridge?

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GoHardSteps") {
      let bridge = StepsBridge()
      steps = bridge
      FlutterMethodChannel(name: "gohard/steps", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in bridge.handle(call, result: result) }
      FlutterEventChannel(name: "gohard/steps/live", binaryMessenger: registrar.messenger()).setStreamHandler(bridge)
    }
  }
}

/// Steps (docs/RUN_WALK.md › Steps) from Core Motion: live counts during a recording, and the day's total from the
/// iPhone's own step history (CMPedometer keeps about 7 days). Motion & Fitness access only; no HealthKit, no
/// entitlement, nothing leaves the phone.
final class StepsBridge: NSObject, FlutterStreamHandler {
  private let pedometer = CMPedometer()
  private var sink: FlutterEventSink?

  static func access() -> String {
    guard CMPedometer.isStepCountingAvailable() else { return "unavailable" }
    switch CMPedometer.authorizationStatus() {
    case .authorized: return "allowed"
    case .notDetermined: return "notAllowed"
    default: return "blocked" // denied or restricted: only Settings can change it
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "access", "dailyAccess":
      result(StepsBridge.access())
    case "request", "dailyRequest":
      guard StepsBridge.access() == "notAllowed" else { result(StepsBridge.access()); return }
      // The first query is what asks for Motion & Fitness access.
      let now = Date()
      pedometer.queryPedometerData(from: now.addingTimeInterval(-60), to: now) { _, _ in
        DispatchQueue.main.async { result(StepsBridge.access()) }
      }
    case "daily":
      guard let args = call.arguments as? [String: Any],
            let from = (args["from"] as? NSNumber)?.doubleValue,
            let to = (args["to"] as? NSNumber)?.doubleValue else { result(nil); return }
      pedometer.queryPedometerData(from: Date(timeIntervalSince1970: from / 1000), to: Date(timeIntervalSince1970: to / 1000)) { data, _ in
        DispatchQueue.main.async {
          if let data = data {
            result(["steps": data.numberOfSteps.intValue, "recorded": true])
          } else {
            result(nil)
          }
        }
      }
    case "vibrate":
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      result(nil)
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CMPedometer.isStepCountingAvailable() else {
      return FlutterError(code: "UNAVAILABLE", message: "No step counting", details: nil)
    }
    sink = events
    let start = Date()
    // Updates count from `start`, so the counter is 0 now: that is the first reading (the baseline).
    events(["c": 0, "t": Int64(start.timeIntervalSince1970 * 1000)])
    pedometer.startUpdates(from: start) { [weak self] data, error in
      DispatchQueue.main.async {
        guard let self = self, let sink = self.sink else { return }
        if let data = data {
          sink(["c": data.numberOfSteps.intValue, "t": Int64(data.endDate.timeIntervalSince1970 * 1000)])
        } else if error != nil {
          sink(FlutterError(code: "STOPPED", message: "Step updates stopped", details: nil))
        }
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    pedometer.stopUpdates()
    sink = nil
    return nil
  }
}
