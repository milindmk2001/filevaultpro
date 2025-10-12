<<<<<<< HEAD

import UIKit
import Flutter

=======
import UIKit
import Flutter

>>>>>>> fa9065d49957c7bcd272dadea7b41a4b2f9ab31b
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // ========================================
        // COMPRESSION CHANNEL
        // ========================================
        let compressionChannel = FlutterMethodChannel(
            name: "com.filevaultpro/compression",
            binaryMessenger: controller.binaryMessenger
        )
        
        compressionChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "compressFolders":
                self?.handleCompressFolders(call: call, result: result)
            case "getDirectorySize":
                self?.handleGetDirectorySize(call: call, result: result)
            case "countItems":
                self?.handleCountItems(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // ========================================
    // COMPRESSION HANDLERS
    // ========================================
    
    private func handleCompressFolders(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let paths = args["paths"] as? [String],
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required arguments: paths, outputPath",
                details: nil
            ))
            return
        }
        
        let preserveStructure = args["preserveStructure"] as? Bool ?? true
        
        // Run compression in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let (success, error) = ZipUtility.createZip(
                paths: paths,
                outputPath: outputPath,
                preserveStructure: preserveStructure
            )
            
            // Return to main thread
            DispatchQueue.main.async {
                if success {
                    result([
                        "success": true,
                        "path": outputPath,
                        "message": "Successfully compressed \(paths.count) item(s)"
                    ])
                } else {
                    result(FlutterError(
                        code: "COMPRESSION_FAILED",
                        message: error ?? "Unknown compression error",
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func handleGetDirectorySize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: path",
                details: nil
            ))
            return
        }
        
        DispatchQueue.global(qos: .utility).async {
            let size = ZipUtility.getDirectorySize(at: path)
            DispatchQueue.main.async {
                result(size)
            }
        }
    }
    
    private func handleCountItems(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: path",
                details: nil
            ))
            return
        }
        
        DispatchQueue.global(qos: .utility).async {
            let count = ZipUtility.countItemsInDirectory(at: path)
            DispatchQueue.main.async {
                result(count)
            }
        }
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> fa9065d49957c7bcd272dadea7b41a4b2f9ab31b
