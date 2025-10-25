import Foundation
import Flutter
import UIKit
import UniformTypeIdentifiers

class FolderPickerHandler: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
    private var result: FlutterResult?
    private var viewController: UIViewController?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.filevaultpro/folder_picker",
            binaryMessenger: registrar.messenger()
        )
        let instance = FolderPickerHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pickFolder":
            pickFolder(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func pickFolder(result: @escaping FlutterResult) {
        self.result = result
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Get the root view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                result(FlutterError(
                    code: "NO_VIEW_CONTROLLER",
                    message: "Could not find root view controller",
                    details: nil
                ))
                return
            }
            
            self.viewController = rootViewController
            
            // Create document picker for folders
            let documentPicker: UIDocumentPickerViewController
            
            if #available(iOS 14.0, *) {
                // iOS 14+: Use UTType for folders
                documentPicker = UIDocumentPickerViewController(
                    forOpeningContentTypes: [.folder],
                    asCopy: false
                )
            } else {
                // iOS 13: Use string identifier
                documentPicker = UIDocumentPickerViewController(
                    documentTypes: ["public.folder"],
                    in: .open
                )
            }
            
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            documentPicker.shouldShowFileExtensions = true
            
            // Present the picker
            if let presentedVC = rootViewController.presentedViewController {
                presentedVC.present(documentPicker, animated: true)
            } else {
                rootViewController.present(documentPicker, animated: true)
            }
        }
    }
    
    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            result?(FlutterError(
                code: "NO_FOLDER_SELECTED",
                message: "No folder was selected",
                details: nil
            ))
            result = nil
            return
        }
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            result?(FlutterError(
                code: "ACCESS_DENIED",
                message: "Could not access the selected folder",
                details: nil
            ))
            result = nil
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Copy folder to app's documents directory
        do {
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            
            let folderName = url.lastPathComponent
            let destinationURL = documentsPath.appendingPathComponent(folderName)
            
            // Remove existing folder if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the folder
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Return the path to Flutter
            result?([
                "success": true,
                "path": destinationURL.path,
                "folderName": folderName
            ])
        } catch {
            result?(FlutterError(
                code: "COPY_ERROR",
                message: "Failed to copy folder: \(error.localizedDescription)",
                details: nil
            ))
        }
        
        result = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        result?(FlutterError(
            code: "PICKER_CANCELLED",
            message: "Folder picker was cancelled",
            details: nil
        ))
        result = nil
    }
}
