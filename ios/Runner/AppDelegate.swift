import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var compressionHandler: CompressionHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        
        // Setup compression method channel
        let compressionChannel = FlutterMethodChannel(
            name: "com.filevaultpro/compression",
            binaryMessenger: controller.binaryMessenger
        )
        
        compressionHandler = CompressionHandler()
        
        compressionChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "Handler not available", details: nil))
                return
            }
            
            self.compressionHandler?.handle(call: call, result: result)
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
