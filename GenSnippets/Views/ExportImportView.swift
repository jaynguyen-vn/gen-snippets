import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportImportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var alertType: AlertType = .none
    @State private var errorMessage = ""
    @State private var exportedFileURL: URL?
    @State private var successMessage = ""
    
    private let localStorageService = LocalStorageService.shared
    
    enum AlertType {
        case none
        case exportSuccess
        case importSuccess
        case error
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Data Management")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            // Export Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Data")
                    .font(.headline)
                
                Text("Export all your categories and snippets to a JSON file")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: exportData) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export to File")
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .focusable(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Import Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Import Data")
                    .font(.headline)
                
                Text("Import categories and snippets from a JSON file")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: importData) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import from File")
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .focusable(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .alert(isPresented: .constant(alertType != .none)) {
            switch alertType {
            case .exportSuccess:
                return Alert(
                    title: Text("Export Successful"),
                    message: Text("Your data has been exported successfully to:\n\(exportedFileURL?.lastPathComponent ?? "")"),
                    primaryButton: .default(Text("Open in Finder")) {
                        if let url = exportedFileURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                        alertType = .none
                        // Close modal after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    },
                    secondaryButton: .default(Text("OK")) {
                        alertType = .none
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            case .importSuccess:
                return Alert(
                    title: Text("Import Successful"),
                    message: Text(successMessage),
                    dismissButton: .default(Text("OK")) {
                        alertType = .none
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            case .error:
                return Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK")) {
                        alertType = .none
                    }
                )
            case .none:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func exportData() {
        if let fileURL = localStorageService.exportData() {
            // Save to user's chosen location
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            savePanel.nameFieldStringValue = "GenSnippets_Export_\(dateFormatter.string(from: Date())).json"
            savePanel.message = "Choose location to save your GenSnippets data"
            
            if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
                do {
                    let data = try Data(contentsOf: fileURL)
                    try data.write(to: destinationURL)
                    exportedFileURL = destinationURL
                    
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Show success alert
                    print("[ExportImport] Export successful to: \(destinationURL.path)")
                    alertType = .exportSuccess
                } catch {
                    errorMessage = "Failed to save export file: \(error.localizedDescription)"
                    print("[ExportImport] Export error: \(error)")
                    alertType = .error
                }
            }
        } else {
            errorMessage = "Failed to export data"
            print("[ExportImport] Failed to create export data")
            alertType = .error
        }
    }
    
    private func importData() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select GenSnippets export file to import"
        
        if openPanel.runModal() == .OK, let fileURL = openPanel.url {
            if localStorageService.importData(from: fileURL) {
                // Get counts for success message
                let categories = localStorageService.loadCategories()
                let snippets = localStorageService.loadSnippets()
                
                successMessage = "Successfully imported:\n• \(categories.count) categories\n• \(snippets.count) snippets"
                
                print("[ExportImport] Import successful: \(categories.count) categories, \(snippets.count) snippets")
                
                // Post notification to refresh UI
                NotificationCenter.default.post(name: NSNotification.Name("RefreshData"), object: nil)
                
                // Show success alert
                alertType = .importSuccess
            } else {
                errorMessage = "Failed to import data. Please check the file format."
                print("[ExportImport] Import failed")
                alertType = .error
            }
        }
    }
}