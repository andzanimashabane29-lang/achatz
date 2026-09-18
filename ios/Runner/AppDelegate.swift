import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let storageChannel = FlutterMethodChannel(name: "com.achatz.app/storage",
                                              binaryMessenger: controller.binaryMessenger)
    storageChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getFreeDiskSpace" {
        do {
          let fileManager = FileManager.default
          let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
          if let freeSpace = attrs[.systemFreeSize] as? Int64 {
            result(freeSpace)
          } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Failed to get systemFreeSize", details: nil))
          }
        } catch {
          result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        }
      } else if call.method == "getTotalDiskSpace" {
        do {
          let fileManager = FileManager.default
          let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
          if let totalSpace = attrs[.systemSize] as? Int64 {
            result(totalSpace)
          } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Failed to get systemSize", details: nil))
          }
        } catch {
          result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
