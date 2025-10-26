import Flutter
import UIKit
import UniformTypeIdentifiers

/// FINAL WORKING VERSION - Auto-tracks current directory
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
            
            let wrapperVC = FolderPickerWrapperViewController()
            wrapperVC.completionHandler = { url in
                self.handleFolderSelection(url: url)
            }
            wrapperVC.cancellationHandler = {
                self.result?(FlutterError(code: "PICKER_CANCELLED", message: "User cancelled", details: nil))
                self.result = nil
                FolderPickerHandler.currentHandler = nil
            }
            
            wrapperVC.modalPresentationStyle = .fullScreen
            
            if let presentedVC = rootViewController.presentedViewController {
                presentedVC.present(wrapperVC, animated: true)
            } else {
                rootViewController.present(wrapperVC, animated: true)
            }
        }
    }
    
    private func handleFolderSelection(url: URL) {
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
        FolderPickerHandler.currentHandler = nil
    }
}

class FolderPickerWrapperViewController: UIViewController {
    var completionHandler: ((URL) -> Void)?
    var cancellationHandler: (() -> Void)?
    
    private var pickerViewController: UIDocumentPickerViewController?
    private var selectButton: UIButton!
    private var instructionLabel: UILabel!
    private var currentDirectoryURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // Set default to Documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            currentDirectoryURL = documentsURL
        }
        
        setupInstructionBar()
        setupSelectButton()
        showDocumentPicker()
    }
    
    private func setupInstructionBar() {
        let instructionBar = UIView()
        instructionBar.backgroundColor = .systemGreen.withAlphaComponent(0.1)
        instructionBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionBar)
        
        let iconLabel = UILabel()
        iconLabel.text = "✅"
        iconLabel.font = .systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionBar.addSubview(iconLabel)
        
        instructionLabel = UILabel()
        instructionLabel.text = "Browse to your folder, then tap the green button"
        instructionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        instructionLabel.textColor = .systemGreen
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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder, .item])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
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
        // Use the tracked current directory URL
        guard let url = currentDirectoryURL else {
            let alert = UIAlertController(
                title: "No Folder Selected",
                message: "Please browse to a folder in the file browser above.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        completionHandler?(url)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        cancellationHandler?()
        dismiss(animated: true)
    }
}

extension FolderPickerWrapperViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Update current directory based on what was tapped
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // User tapped a folder - update current directory to this folder
                currentDirectoryURL = url
            } else {
                // User tapped a file - update current directory to its parent
                currentDirectoryURL = url.deletingLastPathComponent()
            }
        }
        
        // Don't dismiss picker - let user continue browsing or click green button
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User navigating, not actually cancelling
    }
}
