import Flutter
import UIKit
import UniformTypeIdentifiers

/// FIXED - Opens full iOS Files app, not restricted to Documents
class FolderPickerHandler: NSObject {
    private static var channel: FlutterMethodChannel?
    private static var result: FlutterResult?
    
    static func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.filevaultpro/folder_picker", binaryMessenger: messenger)
        
        channel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self.result = result
            
            if call.method == "pickFolder" {
                self.pickFolder()
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private static func pickFolder() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                result?(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot find view controller", details: nil))
                return
            }
            
            let wrapperVC = FolderPickerWrapperViewController()
            wrapperVC.completionHandler = { url in
                self.handleFolderSelection(url: url)
            }
            wrapperVC.cancellationHandler = {
                self.result?(FlutterError(code: "PICKER_CANCELLED", message: "User cancelled", details: nil))
                self.result = nil
            }
            
            wrapperVC.modalPresentationStyle = .fullScreen
            
            if let presentedVC = rootViewController.presentedViewController {
                presentedVC.present(wrapperVC, animated: true)
            } else {
                rootViewController.present(wrapperVC, animated: true)
            }
        }
    }
    
    private static func handleFolderSelection(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            result?(FlutterError(code: "ACCESS_DENIED", message: "Cannot access folder", details: nil))
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
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
    }
}

class FolderPickerWrapperViewController: UIViewController {
    var completionHandler: ((URL) -> Void)?
    var cancellationHandler: (() -> Void)?
    
    private var pickerViewController: UIViewController?
    private var selectButton: UIButton!
    private var instructionLabel: UILabel!
    private var currentFolderURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupInstructionBar()
        setupSelectButton()
        showDocumentPicker()
    }
    
    private func setupInstructionBar() {
        let instructionBar = UIView()
        instructionBar.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        instructionBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionBar)
        
        let iconLabel = UILabel()
        iconLabel.text = "ℹ️"
        iconLabel.font = .systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionBar.addSubview(iconLabel)
        
        instructionLabel = UILabel()
        instructionLabel.text = "Navigate INTO the folder you want, then tap the button below"
        instructionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        instructionLabel.textColor = .systemBlue
        instructionLabel.numberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionBar.addSubview(instructionLabel)
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        instructionBar.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            instructionBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            instructionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            instructionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            instructionBar.heightAnchor.constraint(equalToConstant: 60),
            
            iconLabel.leadingAnchor.constraint(equalTo: instructionBar.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: instructionBar.centerYAnchor),
            
            instructionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            instructionLabel.centerYAnchor.constraint(equalTo: instructionBar.centerYAnchor),
            instructionLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
            closeButton.trailingAnchor.constraint(equalTo: instructionBar.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: instructionBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupSelectButton() {
        selectButton = UIButton(type: .system)
        selectButton.setTitle("📁 Select This Folder", for: .normal)
        selectButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        selectButton.backgroundColor = .systemGreen
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.layer.cornerRadius = 14
        selectButton.layer.shadowColor = UIColor.black.cgColor
        selectButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        selectButton.layer.shadowRadius = 8
        selectButton.layer.shadowOpacity = 0.3
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        view.addSubview(selectButton)
        
        NSLayoutConstraint.activate([
            selectButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            selectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            selectButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func showDocumentPicker() {
        // CRITICAL FIX: Create picker that starts at root browsing location
        // This shows "On My iPhone", "iCloud Drive", etc.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder, .item])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
        // IMPORTANT: Don't set directoryURL - let it open at default browse location
        // This ensures user sees "Locations" view with all available sources
        
        addChild(picker)
        view.insertSubview(picker.view, at: 0)
        picker.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            picker.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            picker.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        picker.didMove(toParent: self)
        pickerViewController = picker
    }
    
    @objc private func selectButtonTapped() {
        if let url = currentFolderURL {
            completionHandler?(url)
            dismiss(animated: true)
        } else {
            let alert = UIAlertController(
                title: "Navigate Into Folder",
                message: "Please navigate into the folder you want to select by tapping on it in the file browser above.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func cancelTapped() {
        cancellationHandler?()
        dismiss(animated: true)
    }
}

extension FolderPickerWrapperViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    currentFolderURL = url
                } else {
                    currentFolderURL = url.deletingLastPathComponent()
                }
            }
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User navigating, not cancelling
    }
}
