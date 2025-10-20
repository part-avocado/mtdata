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
            if viewModel.isLoading {
                // Loading state
                loadingView
            } else if viewModel.metadata == nil {
                // File picker state
                filePickerView
            } else {
                // Metadata editor state
                metadataEditorView
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("MTData", isPresented: $showingAlert) {
            Button("Done") { }
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
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading file...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Reading basic file information")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
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
                    
                    // Extended metadata section (always show, load on-demand)
                    extendedMetadataSection
                    
                    Divider()
                    
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
                
                if viewModel.isLoadingExtendedMetadata {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(action: { 
                    showExtendedMetadata.toggle()
                    // Load extended metadata when section is expanded
                    if showExtendedMetadata && !viewModel.extendedMetadataLoaded {
                        viewModel.loadExtendedMetadata()
                    }
                }) {
                    Image(systemName: showExtendedMetadata ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            
            if showExtendedMetadata {
                if viewModel.isLoadingExtendedMetadata {
                    // Show loading state
                    GroupBox {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Loading extended metadata...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            Spacer()
                        }
                    }
                } else if let extended = viewModel.metadata?.extendedMetadata, viewModel.extendedMetadataLoaded {
                // System & Extended Attributes
                systemAttributesView(extended: extended)
                
                // PDF Metadata
                if extended.pdfPageCount != nil || extended.pdfAuthor != nil {
                    pdfMetadataView(extended: extended)
                }
                
                // Image Metadata
                if extended.exifCameraMake != nil || extended.exifImageWidth != nil || extended.iptcKeywords != nil {
                    imageMetadataView(extended: extended)
                }
                
                // Audio Metadata
                if extended.duration != nil && extended.artist != nil {
                    audioMetadataView(extended: extended)
                }
                
                // Video Metadata
                if extended.videoWidth != nil || extended.subtitleTrackCount != nil {
                    videoMetadataView(extended: extended)
                }
                
                // Document Metadata (Office, ePub)
                if extended.officeTitle != nil || extended.epubTitle != nil {
                    documentMetadataView(extended: extended)
                }
                
                // Text File Metadata
                if extended.textEncoding != nil {
                    textFileMetadataView(extended: extended)
                }
                
                // Archive Metadata
                if extended.archiveFileCount != nil {
                    archiveMetadataView(extended: extended)
                }
                
                // Executable Metadata
                if extended.executableType != nil {
                    executableMetadataView(extended: extended)
                }
                } else if !viewModel.extendedMetadataLoaded {
                    // Not loaded yet - show prompt to load
                    GroupBox {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Extended metadata not loaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Load Extended Metadata") {
                                    viewModel.loadExtendedMetadata()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding()
                            Spacer()
                        }
                    }
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
    
    // MARK: - Extended Metadata Views
    
    @ViewBuilder
    private func systemAttributesView(extended: MTDataExtendedMetadata) -> some View {
        if extended.quarantineInfo != nil || extended.whereFromURLs != nil || extended.finderTags != nil {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("System & Extended Attributes")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    if let quarantine = extended.quarantineInfo {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quarantine Status:")
                                    .fontWeight(.medium)
                                if let agent = quarantine.agentName {
                                    Text("Downloaded via: \(agent)")
                                        .font(.caption)
                                }
                                if let timestamp = quarantine.timestamp {
                                    Text("Date: \(formatDate(timestamp))")
                                        .font(.caption)
                                }
                            }
                            Spacer()
                            Button("Remove Quarantine") {
                                removeQuarantine()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let whereFromURLs = extended.whereFromURLs, !whereFromURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Downloaded From:")
                                .fontWeight(.medium)
                            ForEach(whereFromURLs, id: \.self) { url in
                                Text(url)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    if let tags = extended.finderTags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Finder Tags:")
                                .fontWeight(.medium)
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    if let comment = extended.spotlightComment {
                        metadataRow(label: "Spotlight Comment:", value: comment)
                    }
                }
                .padding(8)
            }
        }
    }
    
    @ViewBuilder
    private func pdfMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("PDF Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if let pageCount = extended.pdfPageCount {
                    metadataRow(label: "Pages:", value: "\(pageCount)")
                }
                if let version = extended.pdfVersion {
                    metadataRow(label: "PDF Version:", value: version)
                }
                if let encrypted = extended.pdfEncrypted {
                    metadataRow(label: "Encrypted:", value: encrypted ? "Yes" : "No")
                }
                if let title = extended.pdfTitle {
                    metadataRow(label: "Title:", value: title)
                }
                if let author = extended.pdfAuthor {
                    metadataRow(label: "Author:", value: author)
                }
                if let subject = extended.pdfSubject {
                    metadataRow(label: "Subject:", value: subject)
                }
                if let producer = extended.pdfProducer {
                    metadataRow(label: "Producer:", value: producer)
                }
                if let created = extended.pdfCreationDate {
                    metadataRow(label: "Created:", value: formatDate(created))
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func imageMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // Dimensions
                if let width = extended.exifImageWidth, let height = extended.exifImageHeight {
                    metadataRow(label: "Dimensions:", value: "\(width) × \(height)")
                }
                if let orientation = extended.exifOrientation {
                    metadataRow(label: "Orientation:", value: orientation)
                }
                
                // Camera
                if let make = extended.exifCameraMake {
                    metadataRow(label: "Camera Make:", value: make)
                }
                if let model = extended.exifCameraModel {
                    metadataRow(label: "Camera Model:", value: model)
                }
                if let lens = extended.exifLensModel {
                    metadataRow(label: "Lens:", value: lens)
                }
                if let serial = extended.exifSerialNumber {
                    metadataRow(label: "Serial Number:", value: serial)
                }
                
                // Settings
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
                if let expComp = extended.exifExposureCompensation {
                    metadataRow(label: "Exposure Comp.:", value: expComp)
                }
                if let wb = extended.exifWhiteBalance {
                    metadataRow(label: "White Balance:", value: wb)
                }
                if let metering = extended.exifMeteringMode {
                    metadataRow(label: "Metering:", value: metering)
                }
                if let dateTaken = extended.exifDateTaken {
                    metadataRow(label: "Date Taken:", value: formatDate(dateTaken))
                }
                
                // GPS
                if let lat = extended.exifGPSLatitude {
                    metadataRow(label: "GPS Latitude:", value: lat)
                }
                if let lon = extended.exifGPSLongitude {
                    metadataRow(label: "GPS Longitude:", value: lon)
                }
                if let alt = extended.exifGPSAltitude {
                    metadataRow(label: "GPS Altitude:", value: alt)
                }
                
                // IPTC
                if let keywords = extended.iptcKeywords, !keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keywords:")
                            .fontWeight(.medium)
                        Text(keywords.joined(separator: ", "))
                            .font(.caption)
                    }
                }
                if let caption = extended.iptcCaption {
                    metadataRow(label: "Caption:", value: caption)
                }
                if let credit = extended.iptcCredit {
                    metadataRow(label: "Credit:", value: credit)
                }
                if let copyright = extended.iptcCopyright {
                    metadataRow(label: "Copyright:", value: copyright)
                }
                
                // XMP
                if let rating = extended.xmpRating {
                    metadataRow(label: "Rating:", value: "\(rating) stars")
                }
                if let creator = extended.xmpCreatorTool {
                    metadataRow(label: "Creator Tool:", value: creator)
                }
                
                // PNG
                if let software = extended.pngSoftware {
                    metadataRow(label: "Software:", value: software)
                }
                
                // HEIC
                if let livePhotoID = extended.heicLivePhotoID {
                    metadataRow(label: "Live Photo ID:", value: livePhotoID)
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func audioMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if let title = extended.title {
                    metadataRow(label: "Title:", value: title)
                }
                if let artist = extended.artist {
                    metadataRow(label: "Artist:", value: artist)
                }
                if let album = extended.album {
                    metadataRow(label: "Album:", value: album)
                }
                if let composer = extended.composer {
                    metadataRow(label: "Composer:", value: composer)
                }
                if let trackNumber = extended.trackNumber {
                    metadataRow(label: "Track Number:", value: "\(trackNumber)")
                }
                if let year = extended.year {
                    metadataRow(label: "Year:", value: year)
                }
                if let genre = extended.genre {
                    metadataRow(label: "Genre:", value: genre)
                }
                if let comment = extended.comment {
                    metadataRow(label: "Comment:", value: comment)
                }
                if let duration = extended.duration {
                    metadataRow(label: "Duration:", value: formatDuration(duration))
                }
                if let bitrate = extended.bitrate {
                    metadataRow(label: "Bitrate:", value: bitrate)
                }
                if let codec = extended.codec {
                    metadataRow(label: "Codec:", value: codec)
                }
                if let albumArt = extended.albumArtPresent, albumArt {
                    metadataRow(label: "Album Art:", value: "Present")
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func videoMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if let title = extended.title {
                    metadataRow(label: "Title:", value: title)
                }
                if let width = extended.videoWidth, let height = extended.videoHeight {
                    metadataRow(label: "Resolution:", value: "\(width) × \(height)")
                }
                if let frameRate = extended.frameRate {
                    metadataRow(label: "Frame Rate:", value: frameRate)
                }
                if let videoCodec = extended.videoCodec {
                    metadataRow(label: "Video Codec:", value: videoCodec)
                }
                if let audioCodec = extended.audioCodec {
                    metadataRow(label: "Audio Codec:", value: audioCodec)
                }
                if let container = extended.containerFormat {
                    metadataRow(label: "Container:", value: container)
                }
                if let duration = extended.duration {
                    metadataRow(label: "Duration:", value: formatDuration(duration))
                }
                if let bitrate = extended.bitrate {
                    metadataRow(label: "Bitrate:", value: bitrate)
                }
                if let audioCount = extended.audioTrackCount, audioCount > 0 {
                    metadataRow(label: "Audio Tracks:", value: "\(audioCount)")
                    if let languages = extended.audioLanguages, !languages.isEmpty {
                        metadataRow(label: "Audio Languages:", value: languages.joined(separator: ", "))
                    }
                }
                if let subCount = extended.subtitleTrackCount, subCount > 0 {
                    metadataRow(label: "Subtitle Tracks:", value: "\(subCount)")
                    if let languages = extended.subtitleLanguages, !languages.isEmpty {
                        metadataRow(label: "Subtitle Languages:", value: languages.joined(separator: ", "))
                    }
                }
                if let created = extended.videoCreationDate {
                    metadataRow(label: "Created:", value: formatDate(created))
                }
                if let location = extended.videoLocation {
                    metadataRow(label: "Location:", value: location)
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func documentMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // Office documents
                if let title = extended.officeTitle {
                    metadataRow(label: "Title:", value: title)
                }
                if let subject = extended.officeSubject {
                    metadataRow(label: "Subject:", value: subject)
                }
                if let creator = extended.officeCreator {
                    metadataRow(label: "Creator:", value: creator)
                }
                if let lastModBy = extended.officeLastModifiedBy {
                    metadataRow(label: "Last Modified By:", value: lastModBy)
                }
                if let created = extended.officeCreated {
                    metadataRow(label: "Created:", value: formatDate(created))
                }
                if let modified = extended.officeModified {
                    metadataRow(label: "Modified:", value: formatDate(modified))
                }
                if let revision = extended.officeRevision {
                    metadataRow(label: "Revision:", value: revision)
                }
                if let app = extended.officeApplication {
                    metadataRow(label: "Application:", value: app)
                }
                
                // ePub documents
                if let title = extended.epubTitle {
                    metadataRow(label: "Title:", value: title)
                }
                if let creator = extended.epubCreator {
                    metadataRow(label: "Creator:", value: creator)
                }
                if let language = extended.epubLanguage {
                    metadataRow(label: "Language:", value: language)
                }
                if let publisher = extended.epubPublisher {
                    metadataRow(label: "Publisher:", value: publisher)
                }
                if let identifier = extended.epubIdentifier {
                    metadataRow(label: "Identifier:", value: identifier)
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func textFileMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Text File Properties")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if let encoding = extended.textEncoding {
                    metadataRow(label: "Encoding:", value: encoding)
                }
                if let bom = extended.textBOMPresent, bom {
                    metadataRow(label: "BOM:", value: "Present")
                }
                if let lineEndings = extended.textLineEndings {
                    metadataRow(label: "Line Endings:", value: lineEndings)
                }
                if let frontMatter = extended.textFrontMatter, !frontMatter.isEmpty {
                    Divider()
                    Text("Front Matter")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(frontMatter.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        metadataRow(label: "\(key):", value: value)
                    }
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func archiveMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Archive Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if let format = extended.archiveFormat {
                    metadataRow(label: "Format:", value: format)
                }
                if let fileCount = extended.archiveFileCount {
                    metadataRow(label: "Files:", value: "\(fileCount)")
                }
                if let totalSize = extended.archiveTotalSize {
                    metadataRow(label: "Total Size:", value: formatFileSize(totalSize))
                }
                if let compression = extended.archiveCompressionMethod {
                    metadataRow(label: "Compression:", value: compression)
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private func executableMetadataView(extended: MTDataExtendedMetadata) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Executable Information")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if let type = extended.executableType {
                    metadataRow(label: "Type:", value: type)
                }
                if let archs = extended.executableArchitectures, !archs.isEmpty {
                    metadataRow(label: "Architectures:", value: archs.joined(separator: ", "))
                }
                if let signed = extended.executableCodeSigned {
                    metadataRow(label: "Code Signed:", value: signed ? "Yes" : "No")
                }
                if let minOS = extended.executableMinimumOS {
                    metadataRow(label: "Minimum OS:", value: minOS)
                }
            }
            .padding(8)
        }
    }
    
    private func removeQuarantine() {
        guard let url = viewModel.metadata?.url else { return }
        let result = FileMetadataManager.shared.removeQuarantineAttribute(from: url)
        
        switch result {
        case .success:
            alertMessage = "Quarantine flag removed successfully!"
            showingAlert = true
            viewModel.reloadMetadata()
        case .failure(let error):
            alertMessage = "Error removing quarantine: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - ViewModel

class MetadataViewModel: ObservableObject {
    @Published var metadata: FileMetadata?
    @Published var originalMetadata: FileMetadata?
    @Published var isLoading = false
    @Published var isLoadingExtendedMetadata = false
    @Published var extendedMetadataLoaded = false
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
        isLoading = true
        extendedMetadataLoaded = false
        
        // Load basic metadata quickly (without extended metadata)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Fast load: only basic file system attributes and MTData fields
            if var loadedMetadata = self?.manager.readMetadata(from: url, includeExtendedMetadata: false) {
                // Load icon on main thread as NSWorkspace/NSImage are not thread-safe
                DispatchQueue.main.async {
                    loadedMetadata.icon = NSWorkspace.shared.icon(forFile: url.path)
                    self?.metadata = loadedMetadata
                    self?.originalMetadata = loadedMetadata
                    self?.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }
    }
    
    func loadExtendedMetadata() {
        guard let url = metadata?.url, !extendedMetadataLoaded, !isLoadingExtendedMetadata else { return }
        
        isLoadingExtendedMetadata = true
        
        // Load extended metadata on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let extendedMetadata = self?.manager.loadExtendedMetadata(for: url)
            
            DispatchQueue.main.async {
                self?.metadata?.extendedMetadata = extendedMetadata ?? MTDataExtendedMetadata()
                self?.originalMetadata?.extendedMetadata = extendedMetadata ?? MTDataExtendedMetadata()
                self?.extendedMetadataLoaded = true
                self?.isLoadingExtendedMetadata = false
            }
        }
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
        isLoading = true
        
        // Determine if we should reload extended metadata
        let shouldLoadExtended = extendedMetadataLoaded
        extendedMetadataLoaded = false
        
        // Reload on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if var loadedMetadata = self?.manager.readMetadata(from: url, includeExtendedMetadata: shouldLoadExtended) {
                // Load icon on main thread as NSWorkspace/NSImage are not thread-safe
                DispatchQueue.main.async {
                    loadedMetadata.icon = NSWorkspace.shared.icon(forFile: url.path)
                    self?.metadata = loadedMetadata
                    self?.originalMetadata = loadedMetadata
                    self?.isLoading = false
                    self?.extendedMetadataLoaded = shouldLoadExtended
                }
            } else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }
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
