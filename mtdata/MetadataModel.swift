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
    var mtdataVersion: String = "1.0"
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
    // PDF Metadata
    var pdfVersion: String?
    var pdfPageCount: Int?
    var pdfAuthor: String?
    var pdfTitle: String?
    var pdfSubject: String?
    var pdfKeywords: String?
    
    // EXIF Data (Images)
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
    var exifImageWidth: Int?
    var exifImageHeight: Int?
    
    // Audio/Video Metadata
    var duration: TimeInterval?
    var bitrate: String?
    var codec: String?
    var videoWidth: Int?
    var videoHeight: Int?
    var frameRate: String?
    var artist: String?
    var album: String?
    var trackNumber: Int?
    var year: String?
    
    var hasAnyData: Bool {
        return pdfVersion != nil || pdfPageCount != nil || pdfAuthor != nil ||
               exifCameraMake != nil || exifCameraModel != nil ||
               duration != nil || artist != nil || album != nil
    }
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

