//
//  MetadataModel.swift
//  mtdata
//
//  Created by MTData
//

import Foundation
import AppKit

struct FileMetadata: Equatable {
    var url: URL
    var name: String
    var creationDate: Date?
    var modificationDate: Date?
    var size: Int64
    var permissions: String
    var fileType: String
    var icon: NSImage?
    
    // MTData tracking fields
    var editedByMTData: Bool = false
    var mtdataVersion: String = "2.0"
    var lastEditDate: Date?
    
    // Custom fields stored in extended attributes
    var customFields: [CustomField] = []
    
    // Extended metadata
    var extendedMetadata: MTDataExtendedMetadata = MTDataExtendedMetadata()
    
    static func == (lhs: FileMetadata, rhs: FileMetadata) -> Bool {
        return lhs.url == rhs.url &&
               lhs.name == rhs.name &&
               lhs.creationDate == rhs.creationDate &&
               lhs.modificationDate == rhs.modificationDate &&
               lhs.size == rhs.size &&
               lhs.permissions == rhs.permissions &&
               lhs.fileType == rhs.fileType &&
               lhs.editedByMTData == rhs.editedByMTData &&
               lhs.mtdataVersion == rhs.mtdataVersion &&
               lhs.lastEditDate == rhs.lastEditDate &&
               lhs.customFields == rhs.customFields &&
               lhs.extendedMetadata == rhs.extendedMetadata
    }
}

struct CustomField: Identifiable, Codable, Equatable {
    var id = UUID()
    var key: String
    var value: String
    
    enum CodingKeys: String, CodingKey {
        case key, value
    }
    
    static func == (lhs: CustomField, rhs: CustomField) -> Bool {
        return lhs.key == rhs.key && lhs.value == rhs.value
    }
}

struct MTDataExtendedMetadata: Equatable {
    // MARK: - System & Extended Attributes
    var quarantineInfo: QuarantineInfo?
    var whereFromURLs: [String]?
    var finderTags: [String]?
    var spotlightComment: String?
    var allExtendedAttributes: [String: String]?
    
    // MARK: - PDF Metadata
    var pdfVersion: String?
    var pdfPageCount: Int?
    var pdfAuthor: String?
    var pdfTitle: String?
    var pdfSubject: String?
    var pdfKeywords: String?
    var pdfProducer: String?
    var pdfCreationDate: Date?
    var pdfModificationDate: Date?
    var pdfEncrypted: Bool?
    var pdfPermissions: String?
    
    // MARK: - EXIF Data (Images - Enhanced)
    var exifCameraMake: String?
    var exifCameraModel: String?
    var exifLensModel: String?
    var exifFocalLength: String?
    var exifAperture: String?
    var exifISO: String?
    var exifShutterSpeed: String?
    var exifDateTaken: Date?
    var exifGPSLatitude: String?
    var exifGPSLongitude: String?
    var exifGPSAltitude: String?
    var exifImageWidth: Int?
    var exifImageHeight: Int?
    var exifOrientation: String?
    var exifExposureCompensation: String?
    var exifWhiteBalance: String?
    var exifMeteringMode: String?
    var exifSerialNumber: String?
    
    // MARK: - IPTC Data (Images)
    var iptcKeywords: [String]?
    var iptcCaption: String?
    var iptcCredit: String?
    var iptcCopyright: String?
    var iptcByline: String?
    
    // MARK: - XMP Data (Images)
    var xmpRating: Int?
    var xmpCreatorTool: String?
    
    // MARK: - PNG Metadata
    var pngSoftware: String?
    var pngCreationTime: String?
    var pngTextChunks: [String: String]?
    
    // MARK: - HEIC/HEIF Metadata
    var heicLivePhotoID: String?
    
    // MARK: - Audio Metadata (Enhanced)
    var duration: TimeInterval?
    var bitrate: String?
    var codec: String?
    var artist: String?
    var album: String?
    var title: String?
    var trackNumber: Int?
    var year: String?
    var genre: String?
    var comment: String?
    var albumArtPresent: Bool?
    var composer: String?
    
    // MARK: - Video Metadata (Enhanced)
    var videoWidth: Int?
    var videoHeight: Int?
    var frameRate: String?
    var videoCodec: String?
    var audioCodec: String?
    var containerFormat: String?
    var videoCreationDate: Date?
    var videoLocation: String?
    var subtitleTrackCount: Int?
    var subtitleLanguages: [String]?
    var audioTrackCount: Int?
    var audioLanguages: [String]?
    var chapterCount: Int?
    var timecode: String?
    
    // MARK: - Office Document Metadata (DOCX/XLSX/PPTX)
    var officeTitle: String?
    var officeSubject: String?
    var officeCreator: String?
    var officeLastModifiedBy: String?
    var officeCreated: Date?
    var officeModified: Date?
    var officeRevision: String?
    var officeTemplate: String?
    var officeApplication: String?
    var officeTotalEditingTime: String?
    
    // MARK: - ePub Metadata
    var epubTitle: String?
    var epubCreator: String?
    var epubLanguage: String?
    var epubIdentifier: String?
    var epubPublisher: String?
    var epubRights: String?
    var epubSpineItemCount: Int?
    
    // MARK: - Text File Metadata
    var textEncoding: String?
    var textBOMPresent: Bool?
    var textLineEndings: String?
    var textFrontMatter: [String: String]?
    
    // MARK: - Archive Metadata
    var archiveFileCount: Int?
    var archiveTotalSize: Int64?
    var archiveCompressionMethod: String?
    var archiveHasComment: Bool?
    var archiveFormat: String?
    
    // MARK: - Executable Metadata
    var executableType: String?
    var executableArchitectures: [String]?
    var executableCodeSigned: Bool?
    var executableMinimumOS: String?
    var executableLinkedFrameworks: Int?
    
    var hasAnyData: Bool {
        return quarantineInfo != nil || whereFromURLs != nil || finderTags != nil ||
               pdfVersion != nil || pdfPageCount != nil || pdfAuthor != nil ||
               exifCameraMake != nil || exifCameraModel != nil ||
               iptcKeywords != nil || xmpRating != nil ||
               pngSoftware != nil || heicLivePhotoID != nil ||
               duration != nil || artist != nil || album != nil ||
               videoWidth != nil || subtitleTrackCount != nil ||
               officeTitle != nil || epubTitle != nil ||
               textEncoding != nil || archiveFileCount != nil ||
               executableType != nil
    }
}

// MARK: - Supporting Structures

struct QuarantineInfo: Equatable {
    var flags: String?
    var timestamp: Date?
    var agentName: String?
    var downloadedFrom: String?
}

extension FileMetadata {
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.creationDate = nil
        self.modificationDate = nil
        self.size = 0
        self.permissions = ""
        self.fileType = ""
        self.icon = nil
        self.customFields = []
        self.extendedMetadata = MTDataExtendedMetadata()
    }
    
    func copy() -> FileMetadata {
        return FileMetadata(
            url: self.url,
            name: self.name,
            creationDate: self.creationDate,
            modificationDate: self.modificationDate,
            size: self.size,
            permissions: self.permissions,
            fileType: self.fileType,
            icon: self.icon,
            editedByMTData: self.editedByMTData,
            mtdataVersion: self.mtdataVersion,
            lastEditDate: self.lastEditDate,
            customFields: self.customFields,
            extendedMetadata: self.extendedMetadata
        )
    }
}

