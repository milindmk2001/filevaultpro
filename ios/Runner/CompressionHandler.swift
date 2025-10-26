import Flutter
import SSZipArchive

class CompressionHandler: NSObject {
    private static var channel: FlutterMethodChannel?
    
    static func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.filevaultpro/compression", binaryMessenger: messenger)
        
        channel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "compressFolder" {
                guard let args = call.arguments as? [String: Any],
                      let sourcePath = args["sourcePath"] as? String,
                      let destinationPath = args["destinationPath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                    return
                }
                
                self.compressFolder(sourcePath: sourcePath, destinationPath: destinationPath, result: result)
            } else if call.method == "extractZip" {
                guard let args = call.arguments as? [String: Any],
                      let zipPath = args["zipPath"] as? String,
                      let destinationPath = args["destinationPath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                    return
                }
                
                self.extractZip(zipPath: zipPath, destinationPath: destinationPath, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private static func compressFolder(sourcePath: String, destinationPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = URL(fileURLWithPath: destinationPath)
            
            // Ensure source exists
            guard FileManager.default.fileExists(atPath: sourcePath) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SOURCE_NOT_FOUND", message: "Source folder does not exist", details: nil))
                }
                return
            }
            
            // Create destination directory if it doesn't exist
            let destinationDir = destinationURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                do {
                    try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DIRECTORY_CREATION_FAILED", message: error.localizedDescription, details: nil))
                    }
                    return
                }
            }
            
            // Delete existing zip if it exists
            if FileManager.default.fileExists(atPath: destinationPath) {
                try? FileManager.default.removeItem(atPath: destinationPath)
            }
            
            // Compress folder
            let success = SSZipArchive.createZipFile(atPath: destinationPath, withContentsOfDirectory: sourcePath)
            
            DispatchQueue.main.async {
                if success {
                    // Get file size
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: destinationPath),
                       let fileSize = attributes[.size] as? UInt64 {
                        let response: [String: Any] = [
                            "success": true,
                            "zipPath": destinationPath,
                            "size": fileSize
                        ]
                        result(response)
                    } else {
                        result(["success": true, "zipPath": destinationPath])
                    }
                } else {
                    result(FlutterError(code: "COMPRESSION_FAILED", message: "Failed to compress folder", details: nil))
                }
            }
        }
    }
    
    private static func extractZip(zipPath: String, destinationPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Ensure zip exists
            guard FileManager.default.fileExists(atPath: zipPath) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ZIP_NOT_FOUND", message: "ZIP file does not exist", details: nil))
                }
                return
            }
            
            // Create destination directory if it doesn't exist
            let destinationURL = URL(fileURLWithPath: destinationPath)
            if !FileManager.default.fileExists(atPath: destinationPath) {
                do {
                    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DIRECTORY_CREATION_FAILED", message: error.localizedDescription, details: nil))
                    }
                    return
                }
            }
            
            // Extract zip
            let success = SSZipArchive.unzipFile(atPath: zipPath, toDestination: destinationPath)
            
            DispatchQueue.main.async {
                if success {
                    result(["success": true, "extractedPath": destinationPath])
                } else {
                    result(FlutterError(code: "EXTRACTION_FAILED", message: "Failed to extract ZIP file", details: nil))
                }
            }
        }
    }
}
