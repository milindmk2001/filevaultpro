import Flutter
import UIKit
import UniformTypeIdentifiers

/// PROPERLY FIXED - Native iOS Folder Selection with Instance Delegate
class FolderPickerHandler: NSObject {
    private static var channel: FlutterMethodChannel?
    private static var currentHandler: FolderPickerHandler?
    private var result: FlutterResult?
    
    static func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.filevaultpro/folder_picker", binaryMessenger: messenger)
        
        channel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "pickFolder" {
                let handler = FolderPickerHandler()
                handler.result = result
                currentHandler = handler
                handler.pickFolder()
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func pickFolder() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                self.result?(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot find view controller", details: nil))
                return
            }
            
            // Create document picker for folder selection
            // Using .folder type only makes tapping a folder SELECT it (not open it)
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            picker.shouldShowFileExtensions = true
            
            // Present picker
            if let presentedVC = rootViewController.presentedViewController {
                presentedVC.present(picker, animated: true)
            } else {
                rootViewController.present(picker, animated: true)
            }
        }
    }
    
    private func handleFolderSelection(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            result?(FlutterError(code: "ACCESS_DENIED", message: "Cannot access folder", details: nil))
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Copy folder to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent(url.lastPathComponent)
        
        try? FileManager.default.removeItem(at: destinationURL)
        
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            let response: [String: Any] = [
                "path": destinationURL.path,
                "name": url.lastPathComponent
            ]
            
            result?(response)
        } catch {
            result?(FlutterError(code: "COPY_FAILED", message: "Failed to copy folder: \(error.localizedDescription)", details: nil))
        }
        
        result = nil
        FolderPickerHandler.currentHandler = nil
    }
}

extension FolderPickerHandler: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            result?(FlutterError(code: "NO_FOLDER", message: "No folder selected", details: nil))
            result = nil
            FolderPickerHandler.currentHandler = nil
            return
        }
        
        // Verify it's a folder
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                handleFolderSelection(url: url)
            } else {
                result?(FlutterError(code: "NOT_FOLDER", message: "Selected item is not a folder", details: nil))
                result = nil
                FolderPickerHandler.currentHandler = nil
            }
        } else {
            result?(FlutterError(code: "NOT_FOUND", message: "Selected folder not found", details: nil))
            result = nil
            FolderPickerHandler.currentHandler = nil
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        result?(FlutterError(code: "PICKER_CANCELLED", message: "User cancelled", details: nil))
        result = nil
        FolderPickerHandler.currentHandler = nil
    }
}
