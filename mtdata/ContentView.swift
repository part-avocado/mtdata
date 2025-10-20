//
//  ContentView.swift
//  mtdata
//
//  Created by James on 2025/10/20.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = MetadataViewModel()
    @State private var showingFilePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var newCustomKey = ""
    @State private var newCustomValue = ""
    @State private var showingAddField = false
    @State private var showingRemoveConfirmation = false
    @State private var showExtendedMetadata = true

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.metadata == nil {
                // File picker state
                filePickerView
            } else {
                // Metadata editor state
                metadataEditorView
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("MTData", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Remove All Metadata", isPresented: $showingRemoveConfirmation) {
            Button("Remove All MTData Metadata", role: .destructive) {
                removeAllMetadata()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all MTData tracking information and custom fields. This action cannot be undone.")
        }
    }
    
    private var filePickerView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("MTData Metadata Editor")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Select a file to view and edit its metadata")
                .foregroundColor(.secondary)
            
            Button(action: selectFile) {
                HStack {
                    Image(systemName: "folder")
                    Text("Select File")
                }
                .frame(width: 150)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("or drag and drop a file here")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private var metadataEditorView: some View {
        VStack(spacing: 0) {
            // Header with file info
            headerView
            
            Divider()
            
            // Scrollable metadata editor
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    systemMetadataSection
                    
                    Divider()
                    
                    // Extended metadata section (if available)
                    if viewModel.metadata?.extendedMetadata.hasAnyData == true {
                        extendedMetadataSection
                        
                        Divider()
                    }
                    
                    mtdataTrackingSection
                    
                    Divider()
                    
                    customFieldsSection
                }
                .padding(20)
            }
            
            Divider()
            
            // Action buttons
            actionButtonsView
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 15) {
            if let icon = viewModel.metadata?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.metadata?.name ?? "")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.metadata?.fileType ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatFileSize(viewModel.metadata?.size ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: closeFile) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var systemMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Metadata")
                .font(.headline)
            
            GroupBox {
                VStack(spacing: 12) {
                    metadataRow(label: "Name:", value: viewModel.metadata?.name ?? "")
                    
                    if let creationDate = viewModel.metadata?.creationDate {
                        DatePicker("Created:", selection: Binding(
                            get: { creationDate },
                            set: { viewModel.metadata?.creationDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .padding(4)
                        .background(viewModel.isCreationDateModified() ? Color.orange.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    
                    if let modDate = viewModel.metadata?.modificationDate {
                        HStack {
                            Text("Modified:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text(formatDate(modDate))
                            Spacer()
                            Text("(read-only)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    metadataRow(label: "Permissions:", value: viewModel.metadata?.permissions ?? "")
                }
                .padding(8)
            }
        }
    }
    
    private var mtdataTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MTData Tracking")
                .font(.headline)
            
            GroupBox {
                VStack(spacing: 8) {
                    if viewModel.metadata?.editedByMTData == true {
                        metadataRow(label: "Edited by:", value: "MTData for macOS")
                        metadataRow(label: "MTData Version:", value: viewModel.metadata?.mtdataVersion ?? "")
                        if let lastEdit = viewModel.metadata?.lastEditDate {
                            metadataRow(label: "Last Edit:", value: formatDate(lastEdit))
                        }
                    } else {
                        Text("Not yet edited by MTData")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(8)
            }
        }
    }
    
    private var extendedMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Extended Metadata")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showExtendedMetadata.toggle() }) {
                    Image(systemName: showExtendedMetadata ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            
            if showExtendedMetadata, let extended = viewModel.metadata?.extendedMetadata {
                GroupBox {
                    VStack(spacing: 8) {
                        // PDF Metadata
                        if extended.pdfPageCount != nil || extended.pdfAuthor != nil {
                            Text("PDF Information")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.secondary)
                            
                            if let pageCount = extended.pdfPageCount {
                                metadataRow(label: "Pages:", value: "\(pageCount)")
                            }
                            if let version = extended.pdfVersion {
                                metadataRow(label: "PDF Version:", value: version)
                            }
                            if let author = extended.pdfAuthor {
                                metadataRow(label: "Author:", value: author)
                            }
                            if let title = extended.pdfTitle {
                                metadataRow(label: "Title:", value: title)
                            }
                            if let subject = extended.pdfSubject {
                                metadataRow(label: "Subject:", value: subject)
                            }
                        }
                        
                        // EXIF Data
                        if extended.exifCameraMake != nil || extended.exifImageWidth != nil {
                            Divider()
                            Text("Image Information")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.secondary)
                            
                            if let width = extended.exifImageWidth, let height = extended.exifImageHeight {
                                metadataRow(label: "Dimensions:", value: "\(width) × \(height)")
                            }
                            if let make = extended.exifCameraMake {
                                metadataRow(label: "Camera Make:", value: make)
                            }
                            if let model = extended.exifCameraModel {
                                metadataRow(label: "Camera Model:", value: model)
                            }
                            if let lens = extended.exifLensModel {
                                metadataRow(label: "Lens:", value: lens)
                            }
                            if let focal = extended.exifFocalLength {
                                metadataRow(label: "Focal Length:", value: focal)
                            }
                            if let aperture = extended.exifAperture {
                                metadataRow(label: "Aperture:", value: aperture)
                            }
                            if let iso = extended.exifISO {
                                metadataRow(label: "ISO:", value: iso)
                            }
                            if let shutter = extended.exifShutterSpeed {
                                metadataRow(label: "Shutter Speed:", value: shutter)
                            }
                            if let lat = extended.exifGPSLatitude, let lon = extended.exifGPSLongitude {
                                metadataRow(label: "GPS:", value: "\(lat), \(lon)")
                            }
                        }
                        
                        // Audio/Video Data
                        if extended.duration != nil || extended.artist != nil {
                            Divider()
                            Text("Audio/Video Information")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.secondary)
                            
                            if let duration = extended.duration {
                                metadataRow(label: "Duration:", value: formatDuration(duration))
                            }
                            if let width = extended.videoWidth, let height = extended.videoHeight {
                                metadataRow(label: "Resolution:", value: "\(width) × \(height)")
                            }
                            if let frameRate = extended.frameRate {
                                metadataRow(label: "Frame Rate:", value: frameRate)
                            }
                            if let codec = extended.codec {
                                metadataRow(label: "Codec:", value: codec)
                            }
                            if let bitrate = extended.bitrate {
                                metadataRow(label: "Bitrate:", value: bitrate)
                            }
                            if let artist = extended.artist {
                                metadataRow(label: "Artist:", value: artist)
                            }
                            if let album = extended.album {
                                metadataRow(label: "Album:", value: album)
                            }
                            if let track = extended.trackNumber {
                                metadataRow(label: "Track:", value: "\(track)")
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
    
    private var customFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom MTData Fields")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddField = true }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
            
            GroupBox {
                if viewModel.metadata?.customFields.isEmpty ?? true {
                    Text("No custom fields yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.metadata?.customFields ?? []) { field in
                            HStack {
                                Text(field.key)
                                    .fontWeight(.medium)
                                    .frame(width: 120, alignment: .leading)
                                
                                TextField("Value", text: Binding(
                                    get: { field.value },
                                    set: { newValue in
                                        if let index = viewModel.metadata?.customFields.firstIndex(where: { $0.id == field.id }) {
                                            viewModel.metadata?.customFields[index].value = newValue
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                
                                Button(action: {
                                    viewModel.metadata?.customFields.removeAll(where: { $0.id == field.id })
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(4)
                            .background(viewModel.isCustomFieldModified(fieldId: field.id) ? Color.orange.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .sheet(isPresented: $showingAddField) {
            addCustomFieldSheet
        }
    }
    
    private var addCustomFieldSheet: some View {
        VStack(spacing: 20) {
            Text("Add Custom Field")
                .font(.headline)
            
            TextField("Key", text: $newCustomKey)
                .textFieldStyle(.roundedBorder)
            
            TextField("Value", text: $newCustomValue)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    showingAddField = false
                    newCustomKey = ""
                    newCustomValue = ""
                }
                
                Spacer()
                
                Button("Add") {
                    let field = CustomField(key: newCustomKey, value: newCustomValue)
                    viewModel.metadata?.customFields.append(field)
                    showingAddField = false
                    newCustomKey = ""
                    newCustomValue = ""
                }
                .disabled(newCustomKey.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private var actionButtonsView: some View {
        HStack {
            Button("Remove All Metadata") {
                showingRemoveConfirmation = true
            }
            .foregroundColor(.red)
            
            Button("Revert") {
                viewModel.reloadMetadata()
            }
            
            Spacer()
            
            Button("Save Changes") {
                saveMetadata()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasUnsavedChanges)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .confirmationDialog(
            "Remove All Metadata",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove All MTData", role: .destructive) {
                removeAllMetadata()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all MTData tracking and custom fields. System metadata will remain unchanged.")
        }
    }
    
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadFile(url: url)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    viewModel.loadFile(url: url)
                }
            }
        }
        return true
    }
    
    private func closeFile() {
        viewModel.metadata = nil
    }
    
    private func saveMetadata() {
        let result = viewModel.saveMetadata()
        switch result {
        case .success:
            alertMessage = "Metadata saved successfully!"
            showingAlert = true
            // Reload to show updated MTData tracking
            viewModel.reloadMetadata()
        case .failure(let error):
            alertMessage = "Error saving metadata: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func removeAllMetadata() {
        let result = viewModel.removeAllMetadata()
        switch result {
        case .success:
            alertMessage = "All MTData metadata removed successfully!"
            showingAlert = true
            viewModel.reloadMetadata()
        case .failure(let error):
            alertMessage = "Error removing metadata: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - ViewModel

class MetadataViewModel: ObservableObject {
    @Published var metadata: FileMetadata?
    @Published var originalMetadata: FileMetadata?
    private let manager = FileMetadataManager.shared
    
    var hasUnsavedChanges: Bool {
        guard let current = metadata, let original = originalMetadata else { return false }
        
        // Check if creation date changed
        if current.creationDate != original.creationDate { return true }
        
        // Check if custom fields changed
        if current.customFields.count != original.customFields.count { return true }
        
        for field in current.customFields {
            if let originalField = original.customFields.first(where: { $0.id == field.id }) {
                if field.value != originalField.value || field.key != originalField.key {
                    return true
                }
            } else {
                return true // New field added
            }
        }
        
        return false
    }
    
    func isCreationDateModified() -> Bool {
        guard let current = metadata?.creationDate, let original = originalMetadata?.creationDate else { return false }
        return current != original
    }
    
    func isCustomFieldModified(fieldId: UUID) -> Bool {
        guard let current = metadata?.customFields.first(where: { $0.id == fieldId }),
              let original = originalMetadata?.customFields.first(where: { $0.id == fieldId }) else {
            // New field
            return metadata?.customFields.contains(where: { $0.id == fieldId }) ?? false
        }
        return current.value != original.value || current.key != original.key
    }
    
    func loadFile(url: URL) {
        metadata = manager.readMetadata(from: url)
        originalMetadata = metadata // Store original for comparison
    }
    
    func saveMetadata() -> Result<Void, Error> {
        guard let metadata = metadata else {
            return .failure(NSError(domain: "MTData", code: 1, userInfo: [NSLocalizedDescriptionKey: "No metadata to save"]))
        }
        let result = manager.saveMetadata(metadata)
        if case .success = result {
            originalMetadata = metadata // Update original after successful save
        }
        return result
    }
    
    func reloadMetadata() {
        guard let url = metadata?.url else { return }
        loadFile(url: url)
    }
    
    func removeAllMetadata() -> Result<Void, Error> {
        guard let url = metadata?.url else {
            return .failure(NSError(domain: "MTData", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file loaded"]))
        }
        return manager.removeAllMTDataMetadata(from: url)
    }
}

#Preview {
    ContentView()
}
