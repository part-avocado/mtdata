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

class FileMetadataExtractor {
    
    // MARK: - Main Extraction Method
    
    static func extractExtendedMetadata(from url: URL) -> MTDataExtendedMetadata {
        var metadata = MTDataExtendedMetadata()
        
        // Determine file type
        guard let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
              let utType = UTType(typeIdentifier) else {
            return metadata
        }
        
        // Extract based on file type
        if utType.conforms(to: .pdf) {
            extractPDFMetadata(from: url, into: &metadata)
        } else if utType.conforms(to: .image) {
            extractEXIFMetadata(from: url, into: &metadata)
        } else if utType.conforms(to: .audio) || utType.conforms(to: .movie) {
            extractAVMetadata(from: url, into: &metadata)
        }
        
        return metadata
    }
    
    // MARK: - PDF Metadata
    
    private static func extractPDFMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
        guard let pdfDocument = PDFDocument(url: url) else { return }
        
        metadata.pdfPageCount = pdfDocument.pageCount
        
        if let attributes = pdfDocument.documentAttributes {
            metadata.pdfTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String
            metadata.pdfAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String
            metadata.pdfSubject = attributes[PDFDocumentAttribute.subjectAttribute] as? String
            if let keywords = attributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                metadata.pdfKeywords = keywords.joined(separator: ", ")
            }
        }
    }
    
    // MARK: - EXIF Metadata
    
    private static func extractEXIFMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
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
        
        // EXIF data
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            metadata.exifCameraMake = exif[kCGImagePropertyExifLensMake as String] as? String
            metadata.exifCameraModel = exif[kCGImagePropertyExifLensModel as String] as? String
            metadata.exifLensModel = exif[kCGImagePropertyExifLensModel as String] as? String
            
            if let aperture = exif[kCGImagePropertyExifApertureValue as String] as? Double {
                metadata.exifAperture = String(format: "f/%.1f", aperture)
            }
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let isoValue = iso.first {
                metadata.exifISO = "\(isoValue)"
            }
            if let shutterSpeed = exif[kCGImagePropertyExifShutterSpeedValue as String] as? Double {
                metadata.exifShutterSpeed = "1/\(Int(pow(2, shutterSpeed)))"
            }
            if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double {
                metadata.exifFocalLength = "\(Int(focalLength))mm"
            }
            if let dateTimeString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                // Parse EXIF date format
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                metadata.exifDateTaken = formatter.date(from: dateTimeString)
            }
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
        }
    }
    
    // MARK: - Audio/Video Metadata
    
    private static func extractAVMetadata(from url: URL, into metadata: inout MTDataExtendedMetadata) {
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
        
        // Track information
        let videoTracks = asset.tracks(withMediaType: .video)
        let audioTracks = asset.tracks(withMediaType: .audio)
        
        if let firstVideo = videoTracks.first {
            let size = firstVideo.naturalSize
            metadata.videoWidth = Int(size.width)
            metadata.videoHeight = Int(size.height)
            metadata.frameRate = String(format: "%.2f fps", firstVideo.nominalFrameRate)
            
            // Codec
            if let descriptions = firstVideo.formatDescriptions as? [CMFormatDescription], let first = descriptions.first {
                let codecValue = CMFormatDescriptionGetMediaSubType(first)
                let codecString = String(format: "%c%c%c%c",
                                        (codecValue >> 24) & 0xff,
                                        (codecValue >> 16) & 0xff,
                                        (codecValue >> 8) & 0xff,
                                        codecValue & 0xff)
                metadata.codec = codecString
            }
        }
        
        // Estimate bitrate
        if let firstTrack = (videoTracks + audioTracks).first {
            let bitrate = firstTrack.estimatedDataRate
            if bitrate > 0 {
                metadata.bitrate = "\(Int(bitrate / 1000)) kbps"
            }
        }
    }
}
