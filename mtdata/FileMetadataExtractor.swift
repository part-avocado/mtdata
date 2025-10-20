//
//  FileMetadataExtractor.swift
//  mtdata
//
//  Created by MTData
//

import Foundation
import AppKit
import ImageIO
import PDFKit
import AVFoundation
import UniformTypeIdentifiers
import CoreServices
import MachO

class FileMetadataExtractor {
    
    // MARK: - Main Extraction Method
    
    static func extractExtendedMetadata(from url: URL) -> MTDataExtendedMetadata {
        var metadata = MTDataExtendedMetadata()
        
        // Always extract system attributes
        extractSystemAttributes(from: url, into: &metadata)
        
        // Determine file type
        guard let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
              let utType = UTType(typeIdentifier) else {
            return metadata
        }
        
        // Extract based on file type
        if utType.conforms(to: .pdf) {
            extractPDFMetadata(from: url, into: &metadata)
        } else if utType.conforms(to: .image) {
            extractAdvancedImageMetadata(from: url, into: &metadata)
        } else if utType.conforms(to: .audio) {
            extractAdvancedAudioMetadata(from: url, into: &metadata)
        } else if utType.conforms(to: .movie) {
            extractAdvancedVideoMetadata(from: url, into: &metadata)
        } else if utType.conforms(to: .plainText) || utType.conforms(to: .sourceCode) {
            extractTextFileMetadata(from: url, into: &metadata)
        } else if isOfficeDocument(utType) {
            extractDocumentMetadata(from: url, into: &metadata)
        } else if isArchive(utType) {
            extractArchiveMetadata(from: url, into: &metadata)
        } else if isExecutable(url) {
            extractExecutableMetadata(from: url, into: &metadata)
        }
        
        return metadata
    }
    
    // MARK: - File Type Detection Helpers
    
    private static func isOfficeDocument(_ utType: UTType) -> Bool {
        let officeTypes = [
            "org.openxmlformats.wordprocessingml.document",
            "org.openxmlformats.spreadsheetml.sheet",
            "org.openxmlformats.presentationml.presentation",
            "org.idpf.epub-container"
        ]
        return officeTypes.contains(where: { utType.identifier == $0 })
    }
    
    private static func isArchive(_ utType: UTType) -> Bool {
        return utType.conforms(to: .archive) || 
               utType.identifier == "public.zip-archive" ||
               utType.identifier == "public.tar-archive" ||
               utType.identifier.hasSuffix(".tar") ||
               utType.identifier.hasSuffix(".gz")
    }
    
    private static func isExecutable(_ url: URL) -> Bool {
        let path = url.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let permissions = attrs[.posixPermissions] as? NSNumber else {
            return false
        }
        // Check if executable bit is set
        let isExec = (permissions.intValue & 0o111) != 0
        
        // Also check for Mach-O magic numbers
        if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            if data.count >= 4 {
                let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
                let machOMagics: [UInt32] = [0xfeedface, 0xfeedfacf, 0xcafebabe, 0xcefaedfe, 0xcffaedfe]
                if machOMagics.contains(magic) {
                    return true
                }
            }
        }
        
        return isExec
    }
    
    // MARK: - System & Extended Attributes
    
    private static func extractSystemAttributes(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        let path = url.path
        
        // Extract all extended attributes
        var allAttrs: [String: String] = [:]
        let bufferSize = listxattr(path, nil, 0, 0)
        if bufferSize > 0 {
            var buffer = [CChar](repeating: 0, count: bufferSize)
            listxattr(path, &buffer, bufferSize, 0)
            
            let attributeNames = String(cString: buffer).components(separatedBy: "\0").filter { !$0.isEmpty }
            for attrName in attributeNames {
                if let value = readExtendedAttribute(url: url, key: attrName) {
                    allAttrs[attrName] = String(data: value, encoding: .utf8) ?? "<binary data>"
                }
            }
        }
        if !allAttrs.isEmpty {
            metadata.allExtendedAttributes = allAttrs
        }
        
        // Extract quarantine info
        if let quarantineData = readExtendedAttribute(url: url, key: "com.apple.quarantine"),
           let quarantineString = String(data: quarantineData, encoding: .utf8) {
            metadata.quarantineInfo = parseQuarantineString(quarantineString)
        }
        
        // Extract where-from URLs
        if let whereFromData = readExtendedAttribute(url: url, key: "com.apple.metadata:kMDItemWhereFroms") {
            metadata.whereFromURLs = parseWhereFromData(whereFromData)
        }
        
        // Extract Finder tags using Spotlight
        if let tags = try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames {
            metadata.finderTags = tags
        }
        
        // Extract Spotlight comment
        if let commentData = readExtendedAttribute(url: url, key: "com.apple.metadata:kMDItemFinderComment") {
            metadata.spotlightComment = String(data: commentData, encoding: .utf8)
        }
    }
    
    private static func readExtendedAttribute(url: URL, key: String) -> Data? {
        let path = url.path
        let size = getxattr(path, key, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { pointer in
            getxattr(path, key, pointer.baseAddress, size, 0, 0)
        }
        
        guard result >= 0 else { return nil }
        return data
    }
    
    private static func parseQuarantineString(_ string: String) -> QuarantineInfo {
        // Quarantine format: flags;timestamp;agent;UUID
        let components = string.components(separatedBy: ";")
        var info = QuarantineInfo()
        
        if components.count > 0 {
            info.flags = components[0]
        }
        if components.count > 1, let timestamp = TimeInterval(components[1]) {
            info.timestamp = Date(timeIntervalSinceReferenceDate: timestamp)
        }
        if components.count > 2 {
            info.agentName = components[2]
        }
        if components.count > 3 {
            info.downloadedFrom = components[3]
        }
        
        return info
    }
    
    private static func parseWhereFromData(_ data: Data) -> [String]? {
        // This is a binary plist
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
                return plist.filter { !$0.isEmpty }
            }
        } catch {
            // Try as string
            if let string = String(data: data, encoding: .utf8) {
                return [string]
            }
        }
        return nil
    }
    
    // MARK: - PDF Metadata
    
    private static func extractPDFMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        guard let pdfDocument = PDFDocument(url: url) else { return }
        
        metadata.pdfPageCount = pdfDocument.pageCount
        metadata.pdfEncrypted = pdfDocument.isEncrypted
        
        if let attributes = pdfDocument.documentAttributes {
            metadata.pdfTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String
            metadata.pdfAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String
            metadata.pdfSubject = attributes[PDFDocumentAttribute.subjectAttribute] as? String
            metadata.pdfProducer = attributes[PDFDocumentAttribute.producerAttribute] as? String
            metadata.pdfCreationDate = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date
            metadata.pdfModificationDate = attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date
            
            if let keywords = attributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                metadata.pdfKeywords = keywords.joined(separator: ", ")
            }
            
            // Extract PDF version if available
            let version = pdfDocument.majorVersion
            let minor = pdfDocument.minorVersion
            metadata.pdfVersion = "\(version).\(minor)"
        }
    }
    
    // MARK: - Advanced Image Metadata
    
    private static func extractAdvancedImageMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return
        }
        
        // Image dimensions
        if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
            metadata.exifImageWidth = pixelWidth
            metadata.exifImageHeight = pixelHeight
        }
        
        // Orientation
        if let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
            metadata.exifOrientation = orientationToString(orientation)
        }
        
        // TIFF data (contains camera make/model)
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            metadata.exifCameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            metadata.exifCameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
            metadata.xmpCreatorTool = tiff[kCGImagePropertyTIFFSoftware as String] as? String
        }
        
        // EXIF data
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            metadata.exifLensModel = exif[kCGImagePropertyExifLensModel as String] as? String
            
            if let aperture = exif[kCGImagePropertyExifFNumber as String] as? Double {
                metadata.exifAperture = String(format: "f/%.1f", aperture)
            } else if let aperture = exif[kCGImagePropertyExifApertureValue as String] as? Double {
                metadata.exifAperture = String(format: "f/%.1f", pow(2, aperture / 2))
            }
            
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let isoValue = iso.first {
                metadata.exifISO = "\(isoValue)"
            }
            
            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                if exposureTime < 1 {
                    metadata.exifShutterSpeed = "1/\(Int(1/exposureTime))"
                } else {
                    metadata.exifShutterSpeed = String(format: "%.1fs", exposureTime)
                }
            }
            
            if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double {
                metadata.exifFocalLength = "\(Int(focalLength))mm"
            }
            
            if let dateTimeString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                metadata.exifDateTaken = formatter.date(from: dateTimeString)
            }
            
            if let expComp = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double {
                metadata.exifExposureCompensation = String(format: "%.1f EV", expComp)
            }
            
            if let wb = exif[kCGImagePropertyExifWhiteBalance as String] as? Int {
                metadata.exifWhiteBalance = wb == 0 ? "Auto" : "Manual"
            }
            
            if let metering = exif[kCGImagePropertyExifMeteringMode as String] as? Int {
                metadata.exifMeteringMode = meteringModeToString(metering)
            }
            
            metadata.exifSerialNumber = exif[kCGImagePropertyExifCameraOwnerName as String] as? String
        }
        
        // GPS data
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                metadata.exifGPSLatitude = "\(lat)° \(latRef)"
            }
            if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                metadata.exifGPSLongitude = "\(lon)° \(lonRef)"
            }
            if let alt = gps[kCGImagePropertyGPSAltitude as String] as? Double {
                metadata.exifGPSAltitude = String(format: "%.1f m", alt)
            }
        }
        
        // IPTC data
        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            metadata.iptcKeywords = iptc[kCGImagePropertyIPTCKeywords as String] as? [String]
            metadata.iptcCaption = iptc[kCGImagePropertyIPTCCaptionAbstract as String] as? String
            metadata.iptcCredit = iptc[kCGImagePropertyIPTCCredit as String] as? String
            metadata.iptcCopyright = iptc[kCGImagePropertyIPTCCopyrightNotice as String] as? String
            metadata.iptcByline = iptc[kCGImagePropertyIPTCByline as String] as? String
        }
        
        // XMP data - using string key as kCGImagePropertyXMPDictionary is not available
        if let xmp = properties["{XMP}" as String] as? [String: Any] {
            // XMP rating is often stored as a string
            if let ratingString = xmp["xmp:Rating"] as? String, let rating = Int(ratingString) {
                metadata.xmpRating = rating
            } else if let rating = xmp["xmp:Rating"] as? Int {
                metadata.xmpRating = rating
            }
        }
        
        // PNG specific metadata
        if let png = properties[kCGImagePropertyPNGDictionary as String] as? [String: Any] {
            metadata.pngSoftware = png[kCGImagePropertyPNGSoftware as String] as? String
            metadata.pngCreationTime = png[kCGImagePropertyPNGCreationTime as String] as? String
            
            // Extract text chunks if available
            var textChunks: [String: String] = [:]
            for (key, value) in png {
                if key.hasPrefix("tEXt:") || key.hasPrefix("iTXt:") {
                    textChunks[key] = value as? String
                }
            }
            if !textChunks.isEmpty {
                metadata.pngTextChunks = textChunks
            }
        }
        
        // HEIF/HEIC metadata
        if let heif = properties[kCGImagePropertyHEIFDictionary as String] as? [String: Any] {
            // Look for live photo pairing UUID
            if let livePhotoID = heif["MakerApple:17"] as? String {
                metadata.heicLivePhotoID = livePhotoID
            }
        }
    }
    
    private static func orientationToString(_ orientation: Int) -> String {
        switch orientation {
        case 1: return "Normal"
        case 2: return "Flipped Horizontal"
        case 3: return "Rotated 180°"
        case 4: return "Flipped Vertical"
        case 5: return "Rotated 90° CCW, Flipped"
        case 6: return "Rotated 90° CW"
        case 7: return "Rotated 90° CW, Flipped"
        case 8: return "Rotated 90° CCW"
        default: return "Unknown (\(orientation))"
        }
    }
    
    private static func meteringModeToString(_ mode: Int) -> String {
        switch mode {
        case 0: return "Unknown"
        case 1: return "Average"
        case 2: return "Center Weighted Average"
        case 3: return "Spot"
        case 4: return "Multi-Spot"
        case 5: return "Pattern"
        case 6: return "Partial"
        default: return "Other (\(mode))"
        }
    }
    
    // MARK: - Advanced Audio Metadata
    
    private static func extractAdvancedAudioMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        let asset = AVAsset(url: url)
        
        // Duration
        let duration = asset.duration
        if duration.seconds > 0 {
            metadata.duration = duration.seconds
        }
        
        // Common metadata
        for item in asset.commonMetadata {
            guard let key = item.commonKey else { continue }
            
            switch key {
            case .commonKeyTitle:
                metadata.title = item.stringValue
            case .commonKeyArtist:
                metadata.artist = item.stringValue
            case .commonKeyAlbumName:
                metadata.album = item.stringValue
            case .commonKeyCreationDate:
                if let dateString = item.stringValue {
                    metadata.year = String(dateString.prefix(4))
                }
            default:
                break
            }
        }
        
        // iTunes metadata (for M4A, MP4 audio)
        for item in asset.metadata {
            if item.keySpace == .iTunes {
                if let key = item.key as? String {
                    switch key {
                    case "©nam": metadata.title = item.stringValue
                    case "©ART": metadata.artist = item.stringValue
                    case "©alb": metadata.album = item.stringValue
                    case "©day": metadata.year = item.stringValue
                    case "©gen": metadata.genre = item.stringValue
                    case "©cmt": metadata.comment = item.stringValue
                    case "©wrt": metadata.composer = item.stringValue
                    case "trkn":
                        if let data = item.dataValue, data.count >= 4 {
                            let trackNum = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }
                            metadata.trackNumber = Int(trackNum.bigEndian)
                        }
                    case "covr":
                        metadata.albumArtPresent = item.dataValue != nil
                    default:
                        break
                    }
                }
            } else if item.keySpace == .id3 {
                // ID3 tags for MP3
                if let key = item.key as? String {
                    switch key {
                    case "TIT2": metadata.title = item.stringValue
                    case "TPE1": metadata.artist = item.stringValue
                    case "TALB": metadata.album = item.stringValue
                    case "TYER", "TDRC": metadata.year = item.stringValue
                    case "TCON": metadata.genre = item.stringValue
                    case "COMM": metadata.comment = item.stringValue
                    case "TCOM": metadata.composer = item.stringValue
                    case "TRCK":
                        if let trackString = item.stringValue, let track = Int(trackString.components(separatedBy: "/").first ?? "") {
                            metadata.trackNumber = track
                        }
                    case "APIC":
                        metadata.albumArtPresent = item.dataValue != nil
                    default:
                        break
                    }
                }
            }
        }
        
        // Audio track information
        let audioTracks = asset.tracks(withMediaType: .audio)
        if let firstAudio = audioTracks.first {
            let bitrate = firstAudio.estimatedDataRate
            if bitrate > 0 {
                metadata.bitrate = "\(Int(bitrate / 1000)) kbps"
            }
            
            // Codec
            if let descriptions = firstAudio.formatDescriptions as? [CMFormatDescription], let first = descriptions.first {
                let codecValue = CMFormatDescriptionGetMediaSubType(first)
                let codecString = String(format: "%c%c%c%c",
                                        (codecValue >> 24) & 0xff,
                                        (codecValue >> 16) & 0xff,
                                        (codecValue >> 8) & 0xff,
                                        codecValue & 0xff)
                metadata.codec = codecString
            }
        }
    }
    
    // MARK: - Advanced Video Metadata
    
    private static func extractAdvancedVideoMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        let asset = AVAsset(url: url)
        
        // Duration
        let duration = asset.duration
        if duration.seconds > 0 {
            metadata.duration = duration.seconds
        }
        
        // Common metadata
        for item in asset.commonMetadata {
            guard let key = item.commonKey else { continue }
            
            switch key {
            case .commonKeyTitle:
                metadata.title = item.stringValue
            case .commonKeyCreationDate:
                if let dateString = item.stringValue {
                    let formatter = ISO8601DateFormatter()
                    metadata.videoCreationDate = formatter.date(from: dateString)
                }
            case .commonKeyLocation:
                if let locationString = item.stringValue {
                    metadata.videoLocation = locationString
                } else if let locationData = item.dataValue {
                    // Parse ISO 6709 location format
                    if let locString = String(data: locationData, encoding: .utf8) {
                        metadata.videoLocation = locString
                    }
                }
            default:
                break
            }
        }
        
        // QuickTime metadata
        for item in asset.metadata {
            if item.keySpace == .quickTimeMetadata {
                if let key = item.key as? String {
                    switch key {
                    case "com.apple.quicktime.location.ISO6709":
                        metadata.videoLocation = item.stringValue
                    case "com.apple.quicktime.creationdate":
                        if let dateString = item.stringValue {
                            let formatter = ISO8601DateFormatter()
                            metadata.videoCreationDate = formatter.date(from: dateString)
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        // Track information
        let videoTracks = asset.tracks(withMediaType: .video)
        let audioTracks = asset.tracks(withMediaType: .audio)
        let subtitleTracks = asset.tracks(withMediaType: .subtitle) + asset.tracks(withMediaType: .closedCaption)
        
        // Video track details
        if let firstVideo = videoTracks.first {
            let size = firstVideo.naturalSize
            metadata.videoWidth = Int(size.width)
            metadata.videoHeight = Int(size.height)
            metadata.frameRate = String(format: "%.2f fps", firstVideo.nominalFrameRate)
            
            // Video codec
            if let descriptions = firstVideo.formatDescriptions as? [CMFormatDescription], let first = descriptions.first {
                let codecValue = CMFormatDescriptionGetMediaSubType(first)
                let codecString = String(format: "%c%c%c%c",
                                        (codecValue >> 24) & 0xff,
                                        (codecValue >> 16) & 0xff,
                                        (codecValue >> 8) & 0xff,
                                        codecValue & 0xff)
                metadata.videoCodec = codecString
            }
            
            let bitrate = firstVideo.estimatedDataRate
            if bitrate > 0 {
                metadata.bitrate = "\(Int(bitrate / 1000)) kbps"
            }
        }
        
        // Audio track details
        if let firstAudio = audioTracks.first {
            if let descriptions = firstAudio.formatDescriptions as? [CMFormatDescription], let first = descriptions.first {
                let codecValue = CMFormatDescriptionGetMediaSubType(first)
                let codecString = String(format: "%c%c%c%c",
                                        (codecValue >> 24) & 0xff,
                                        (codecValue >> 16) & 0xff,
                                        (codecValue >> 8) & 0xff,
                                        codecValue & 0xff)
                metadata.audioCodec = codecString
            }
        }
        
        // Audio track count and languages
        metadata.audioTrackCount = audioTracks.count
        if !audioTracks.isEmpty {
            var languages: [String] = []
            for track in audioTracks {
                if let langCode = track.languageCode {
                    languages.append(langCode)
                }
            }
            if !languages.isEmpty {
                metadata.audioLanguages = languages
            }
        }
        
        // Subtitle track count and languages
        metadata.subtitleTrackCount = subtitleTracks.count
        if !subtitleTracks.isEmpty {
            var languages: [String] = []
            for track in subtitleTracks {
                if let langCode = track.languageCode {
                    languages.append(langCode)
                }
            }
            if !languages.isEmpty {
                metadata.subtitleLanguages = languages
            }
        }
        
        // Container format
        if let fileExtension = url.pathExtension.lowercased() as String? {
            metadata.containerFormat = fileExtension.uppercased()
        }
    }
    
    // MARK: - Document Metadata (Office, ePub)
    
    private static func extractDocumentMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        let ext = url.pathExtension.lowercased()
        
        if ext == "docx" || ext == "xlsx" || ext == "pptx" {
            extractOfficeMetadata(from: url, into: &metadata)
        } else if ext == "epub" {
            extractEPubMetadata(from: url, into: &metadata)
        }
    }
    
    private static func extractOfficeMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        // Office files are ZIP archives containing XML files
        guard let archive = try? Data(contentsOf: url) else { return }
        
        // Use unzip to extract core.xml
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Try to extract using command line unzip
        let corePropsPath = tempDir.appendingPathComponent("docProps/core.xml")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", "-o", url.path, "docProps/core.xml", "-d", tempDir.path]
        try? process.run()
        process.waitUntilExit()
        
        if let coreXML = try? String(contentsOf: corePropsPath) {
            // Parse XML for core properties
            metadata.officeTitle = extractXMLValue(from: coreXML, tag: "dc:title") ?? extractXMLValue(from: coreXML, tag: "title")
            metadata.officeSubject = extractXMLValue(from: coreXML, tag: "dc:subject") ?? extractXMLValue(from: coreXML, tag: "subject")
            metadata.officeCreator = extractXMLValue(from: coreXML, tag: "dc:creator") ?? extractXMLValue(from: coreXML, tag: "creator")
            metadata.officeLastModifiedBy = extractXMLValue(from: coreXML, tag: "cp:lastModifiedBy")
            metadata.officeRevision = extractXMLValue(from: coreXML, tag: "cp:revision")
            
            if let createdStr = extractXMLValue(from: coreXML, tag: "dcterms:created") {
                let formatter = ISO8601DateFormatter()
                metadata.officeCreated = formatter.date(from: createdStr)
            }
            if let modifiedStr = extractXMLValue(from: coreXML, tag: "dcterms:modified") {
                let formatter = ISO8601DateFormatter()
                metadata.officeModified = formatter.date(from: modifiedStr)
            }
        }
        
        // Try to extract app.xml for application info
        let appPropsPath = tempDir.appendingPathComponent("docProps/app.xml")
        let appProcess = Process()
        appProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        appProcess.arguments = ["-qq", "-o", url.path, "docProps/app.xml", "-d", tempDir.path]
        try? appProcess.run()
        appProcess.waitUntilExit()
        
        if let appXML = try? String(contentsOf: appPropsPath) {
            metadata.officeApplication = extractXMLValue(from: appXML, tag: "Application")
            metadata.officeTemplate = extractXMLValue(from: appXML, tag: "Template")
            metadata.officeTotalEditingTime = extractXMLValue(from: appXML, tag: "TotalTime")
        }
    }
    
    private static func extractEPubMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Extract container.xml
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", "-o", url.path, "META-INF/container.xml", "-d", tempDir.path]
        try? process.run()
        process.waitUntilExit()
        
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        guard let containerXML = try? String(contentsOf: containerPath),
              let opfPath = extractOPFPath(from: containerXML) else { return }
        
        // Extract OPF file
        let opfProcess = Process()
        opfProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        opfProcess.arguments = ["-qq", "-o", url.path, opfPath, "-d", tempDir.path]
        try? opfProcess.run()
        opfProcess.waitUntilExit()
        
        let opfURL = tempDir.appendingPathComponent(opfPath)
        if let opfXML = try? String(contentsOf: opfURL) {
            metadata.epubTitle = extractXMLValue(from: opfXML, tag: "dc:title")
            metadata.epubCreator = extractXMLValue(from: opfXML, tag: "dc:creator")
            metadata.epubLanguage = extractXMLValue(from: opfXML, tag: "dc:language")
            metadata.epubIdentifier = extractXMLValue(from: opfXML, tag: "dc:identifier")
            metadata.epubPublisher = extractXMLValue(from: opfXML, tag: "dc:publisher")
            metadata.epubRights = extractXMLValue(from: opfXML, tag: "dc:rights")
        }
    }
    
    private static func extractXMLValue(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>(.+?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        return String(xml[range])
    }
    
    private static func extractOPFPath(from containerXML: String) -> String? {
        let pattern = "full-path=\"([^\"]+\\.opf)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: containerXML, range: NSRange(containerXML.startIndex..., in: containerXML)),
              let range = Range(match.range(at: 1), in: containerXML) else {
            return nil
        }
        return String(containerXML[range])
    }
    
    // MARK: - Text File Metadata
    
    private static func extractTextFileMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        guard let data = try? Data(contentsOf: url) else { return }
        
        // Detect BOM
        if data.count >= 3 {
            let bom = data.prefix(3)
            if bom[0] == 0xEF && bom[1] == 0xBB && bom[2] == 0xBF {
                metadata.textBOMPresent = true
                metadata.textEncoding = "UTF-8 with BOM"
            } else if data.count >= 2 {
                let bom2 = data.prefix(2)
                if bom2[0] == 0xFF && bom2[1] == 0xFE {
                    metadata.textBOMPresent = true
                    metadata.textEncoding = "UTF-16 LE"
                } else if bom2[0] == 0xFE && bom2[1] == 0xFF {
                    metadata.textBOMPresent = true
                    metadata.textEncoding = "UTF-16 BE"
                }
            }
        }
        
        // Try to decode as string to determine encoding
        if metadata.textEncoding == nil {
            if let _ = String(data: data, encoding: .utf8) {
                metadata.textEncoding = "UTF-8"
            } else if let _ = String(data: data, encoding: .utf16) {
                metadata.textEncoding = "UTF-16"
            } else if let _ = String(data: data, encoding: .ascii) {
                metadata.textEncoding = "ASCII"
            } else if let _ = String(data: data, encoding: .isoLatin1) {
                metadata.textEncoding = "ISO-8859-1"
            } else {
                metadata.textEncoding = "Unknown"
            }
        }
        
        // Detect line endings
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            let hasCRLF = text.contains("\r\n")
            let hasCR = text.contains("\r") && !hasCRLF
            let hasLF = text.contains("\n") && !hasCRLF
            
            if hasCRLF {
                metadata.textLineEndings = "CRLF (Windows)"
            } else if hasLF {
                metadata.textLineEndings = "LF (Unix)"
            } else if hasCR {
                metadata.textLineEndings = "CR (Classic Mac)"
            } else {
                metadata.textLineEndings = "None (Single Line)"
            }
            
            // Try to extract front matter (YAML/TOML at start of Markdown files)
            if url.pathExtension.lowercased() == "md" || url.pathExtension.lowercased() == "markdown" {
                if text.hasPrefix("---") {
                    let components = text.components(separatedBy: "---")
                    if components.count >= 3 {
                        let frontMatter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        var fmDict: [String: String] = [:]
                        for line in frontMatter.components(separatedBy: "\n") {
                            let parts = line.components(separatedBy: ":")
                            if parts.count >= 2 {
                                let key = parts[0].trimmingCharacters(in: .whitespaces)
                                let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                                fmDict[key] = value
                            }
                        }
                        if !fmDict.isEmpty {
                            metadata.textFrontMatter = fmDict
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Archive Metadata
    
    private static func extractArchiveMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        let ext = url.pathExtension.lowercased()
        
        if ext == "zip" {
            extractZIPMetadata(from: url, into: &metadata)
        } else if ext == "tar" || ext == "gz" || ext == "tgz" {
            extractTARMetadata(from: url, into: &metadata)
        }
    }
    
    private static func extractZIPMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        metadata.archiveFormat = "ZIP"
        
        // Use zipinfo command if available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.arguments = ["-t", url.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                metadata.archiveFileCount = lines.filter { !$0.isEmpty && !$0.hasPrefix("Archive:") }.count
            }
        } catch {
            // Fallback: try to read ZIP directory manually
            if let data = try? Data(contentsOf: url) {
                // Look for end of central directory signature
                let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
                if let eocdIndex = data.lastIndex(where: { _ in true }) {
                    // This is simplified - real ZIP parsing is more complex
                    metadata.archiveFileCount = 0 // Placeholder
                }
            }
        }
    }
    
    private static func extractTARMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        metadata.archiveFormat = "TAR"
        
        // Use tar command to list contents
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.arguments = ["-tzf", url.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                metadata.archiveFileCount = lines.count
            }
        } catch {
            // Failed to read TAR
        }
    }
    
    // MARK: - Executable Metadata
    
    private static func extractExecutableMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        guard let data = try? Data(contentsOf: url) else { return }
        
        if data.count < 4 { return }
        
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        // Mach-O formats
        if magic == 0xfeedface || magic == 0xcefaedfe {
            extractMachOMetadata(from: url, data: data, is64bit: false, into: &metadata)
        } else if magic == 0xfeedfacf || magic == 0xcffaedfe {
            extractMachOMetadata(from: url, data: data, is64bit: true, into: &metadata)
        } else if magic == 0xcafebabe || magic == 0xbebafeca {
            // Universal binary (fat binary)
            metadata.executableType = "Mach-O Universal Binary"
            extractFatBinaryMetadata(from: url, data: data, into: &metadata)
        }
    }
    
    private static func extractMachOMetadata(from url: URL, data: Data, is64bit: Bool, into metadata: inout MTDataExtendedMetadata) {
        metadata.executableType = "Mach-O \(is64bit ? "64-bit" : "32-bit")"
        
        // Use file command for architecture info
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.arguments = [url.path]
        
        try? process.run()
        process.waitUntilExit()
        
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        if let fileOutput = String(data: output, encoding: .utf8) {
            if fileOutput.contains("x86_64") {
                metadata.executableArchitectures = ["x86_64"]
            } else if fileOutput.contains("arm64") {
                metadata.executableArchitectures = ["arm64"]
            }
        }
        
        // Check code signature
        let codesignProcess = Process()
        codesignProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        let codesignPipe = Pipe()
        codesignProcess.standardOutput = codesignPipe
        codesignProcess.arguments = ["-dv", url.path]
        
        try? codesignProcess.run()
        codesignProcess.waitUntilExit()
        
        metadata.executableCodeSigned = codesignProcess.terminationStatus == 0
    }
    
    private static func extractFatBinaryMetadata(from url: URL, data: Data, into metadata: inout MTDataExtendedMetadata) {
        // Use lipo to get architectures
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.arguments = ["-info", url.path]
        
        try? process.run()
        process.waitUntilExit()
        
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        if let lipoOutput = String(data: output, encoding: .utf8) {
            // Parse output like "Architectures in the fat file: ... are: x86_64 arm64"
            let components = lipoOutput.components(separatedBy: ":")
            if components.count >= 2 {
                let archStr = components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let archs = archStr.components(separatedBy: " ").filter { !$0.isEmpty }
                if !archs.isEmpty {
                    metadata.executableArchitectures = archs
                }
            }
        }
        
        // Check code signature
        let codesignProcess = Process()
        codesignProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesignProcess.arguments = ["-dv", url.path]
        try? codesignProcess.run()
        codesignProcess.waitUntilExit()
        
        metadata.executableCodeSigned = codesignProcess.terminationStatus == 0
    }
}
