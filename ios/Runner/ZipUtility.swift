import Foundation

class ZipUtility {
    
    /// Compress single or multiple files/folders into a ZIP
    /// Uses the system zip utility for maximum compatibility
    static func createZip(paths: [String], outputPath: String, preserveStructure: Bool = true) -> (success: Bool, error: String?) {
        
        let fileManager = FileManager.default
        
        // Validate all input paths exist
        for path in paths {
            if !fileManager.fileExists(atPath: path) {
                return (false, "Path does not exist: \(path)")
            }
        }
        
        // Delete existing output file if it exists
        if fileManager.fileExists(atPath: outputPath) {
            do {
                try fileManager.removeItem(atPath: outputPath)
            } catch {
                return (false, "Could not remove existing file: \(error.localizedDescription)")
            }
        }
        
        // Use system zip utility
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        var arguments = ["-r", "-q"] // recursive, quiet mode
        arguments.append(outputPath)
        
        if preserveStructure {
            // Get common parent directory
            let firstPath = URL(fileURLWithPath: paths[0])
            let parentDir = firstPath.deletingLastPathComponent()
            task.currentDirectoryURL = parentDir
            
            // Add relative paths to preserve folder structure
            for path in paths {
                let url = URL(fileURLWithPath: path)
                let relativePath = url.lastPathComponent
                arguments.append(relativePath)
            }
        } else {
            // Use absolute paths (flattens structure)
            arguments.append(contentsOf: paths)
        }
        
        task.arguments = arguments
        
        // Capture stderr for error messages
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return (true, nil)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return (false, "ZIP creation failed: \(errorMessage)")
            }
        } catch {
            return (false, "Error executing zip command: \(error.localizedDescription)")
        }
    }
    
    /// Get all items in a directory recursively
    static func enumerateDirectory(at path: String) -> [String] {
        let fileManager = FileManager.default
        var items: [String] = []
        
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return items
        }
        
        for case let item as String in enumerator {
            let fullPath = (path as NSString).appendingPathComponent(item)
            items.append(fullPath)
        }
        
        return items
    }
    
    /// Get directory size recursively
    static func getDirectorySize(at path: String) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    /// Count items in directory recursively
    static func countItemsInDirectory(at path: String) -> Int {
        let items = enumerateDirectory(at: path)
        return items.count
    }
}