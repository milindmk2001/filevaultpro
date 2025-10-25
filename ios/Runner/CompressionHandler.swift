import Foundation
import Flutter
import SSZipArchive

class CompressionHandler: NSObject {
    
    /// Handle method channel calls from Flutter
    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "compressFolders":
            compressFolders(call: call, result: result)
        case "getDirectorySize":
            getDirectorySize(call: call, result: result)
        case "countItems":
            countItems(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Compression
    
    private func compressFolders(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let paths = args["paths"] as? [String],
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required arguments: paths or outputPath",
                details: nil
            ))
            return
        }
        
        let preserveStructure = args["preserveStructure"] as? Bool ?? true
        
        // Validate paths exist
        for path in paths {
            if !FileManager.default.fileExists(atPath: path) {
                result(FlutterError(
                    code: "FILE_NOT_FOUND",
                    message: "Path does not exist: \(path)",
                    details: nil
                ))
                return
            }
        }
        
        // Perform compression in background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let success = try self.createZipArchive(
                    paths: paths,
                    outputPath: outputPath,
                    preserveStructure: preserveStructure
                )
                
                DispatchQueue.main.async {
                    if success {
                        result([
                            "success": true,
                            "path": outputPath,
                            "message": "Compression completed successfully"
                        ])
                    } else {
                        result(FlutterError(
                            code: "COMPRESSION_FAILED",
                            message: "Failed to create zip archive",
                            details: nil
                        ))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "COMPRESSION_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func createZipArchive(paths: [String], outputPath: String, preserveStructure: Bool) throws -> Bool {
        // Delete existing zip if it exists
        if FileManager.default.fileExists(atPath: outputPath) {
            try FileManager.default.removeItem(atPath: outputPath)
        }
        
        // Create zip archive
        let success = SSZipArchive.createZipFile(
            atPath: outputPath,
            withContentsOfDirectory: "", // We'll add files manually
            keepParentDirectory: preserveStructure
        )
        
        guard success else {
            return false
        }
        
        // Add each path to the archive
        return try addPathsToZip(paths: paths, zipPath: outputPath, preserveStructure: preserveStructure)
    }
    
    private func addPathsToZip(paths: [String], zipPath: String, preserveStructure: Bool) throws -> Bool {
        // For multiple paths, we need to add them individually
        // This requires using SSZipArchive's addFileToZip method
        
        var filesToAdd: [String] = []
        
        for sourcePath in paths {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                // Get all files in directory
                let files = try getFilesRecursively(in: sourcePath)
                filesToAdd.append(contentsOf: files)
            } else {
                // Single file
                filesToAdd.append(sourcePath)
            }
        }
        
        // Create zip with all collected files
        let success = SSZipArchive.createZipFile(
            atPath: zipPath,
            withFilesAtPaths: filesToAdd
        )
        
        return success
    }
    
    private func getFilesRecursively(in directory: String) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            throw NSError(
                domain: "CompressionHandler",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate directory"]
            )
        }
        
        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (directory as NSString).appendingPathComponent(relativePath)
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    files.append(fullPath)
                }
            }
        }
        
        return files
    }
    
    // MARK: - Directory Size
    
    private func getDirectorySize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: path",
                details: nil
            ))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let size = try self.calculateDirectorySize(at: path)
                DispatchQueue.main.async {
                    result(size)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "SIZE_CALCULATION_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func calculateDirectorySize(at path: String) throws -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw NSError(
                domain: "CompressionHandler",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate directory"]
            )
        }
        
        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            } catch {
                // Skip files that can't be accessed
                continue
            }
        }
        
        return totalSize
    }
    
    // MARK: - Count Items
    
    private func countItems(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: path",
                details: nil
            ))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try self.countItemsInDirectory(at: path)
                DispatchQueue.main.async {
                    result(count)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "COUNT_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func countItemsInDirectory(at path: String) throws -> Int {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw NSError(
                domain: "CompressionHandler",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate directory"]
            )
        }
        
        var count = 0
        while enumerator.nextObject() != nil {
            count += 1
        }
        
        return count
    }
}
