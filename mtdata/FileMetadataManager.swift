//
//  FileMetadataManager.swift
//  mtdata
//
//  Created by MTData
//

import Foundation
import AppKit

class FileMetadataManager {
    static let shared = FileMetadataManager()
    
    private let mtdataVersion = "2.0"
    private let customFieldsKey = "com.mtdata.customfields"
    private let editedByKey = "com.mtdata.editedby"
    private let versionKey = "com.mtdata.version"
    private let lastEditKey = "com.mtdata.lastedit"
    
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Read Metadata
    
    func readMetadata(from url: URL, includeExtendedMetadata: Bool = false) -> FileMetadata? {
        var metadata = FileMetadata(url: url)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let resourceValues = try url.resourceValues(forKeys: [
                .creationDateKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .typeIdentifierKey
            ])
            
            metadata.name = url.lastPathComponent
            metadata.creationDate = resourceValues.creationDate
            metadata.modificationDate = resourceValues.contentModificationDate
            metadata.size = Int64(resourceValues.fileSize ?? 0)
            metadata.fileType = resourceValues.typeIdentifier ?? "Unknown"
            
            // Icon must be loaded on main thread as NSWorkspace/NSImage are not thread-safe
            // We'll load it separately after returning
            metadata.icon = nil
            
            // Get permissions
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                metadata.permissions = String(format: "%o", posixPermissions.intValue)
            }
            
            // Read MTData tracking fields from extended attributes
            metadata.editedByMTData = readExtendedAttribute(url: url, key: editedByKey) != nil
            if let versionData = readExtendedAttribute(url: url, key: versionKey),
               let version = String(data: versionData, encoding: .utf8) {
                metadata.mtdataVersion = version
            }
            if let editDateData = readExtendedAttribute(url: url, key: lastEditKey),
               let editDateString = String(data: editDateData, encoding: .utf8),
               let editDate = ISO8601DateFormatter().date(from: editDateString) {
                metadata.lastEditDate = editDate
            }
            
            // Read custom fields
            metadata.customFields = readCustomFields(from: url)
            
            // Extract extended metadata only if requested (lazy loading)
            if includeExtendedMetadata {
                metadata.extendedMetadata = FileMetadataExtractor.extractExtendedMetadata(from: url)
            }
            
            return metadata
        } catch {
            print("Error reading metadata: \(error)")
            return nil
        }
    }
    
    // MARK: - Load Extended Metadata Separately
    
    func loadExtendedMetadata(for url: URL) -> MTDataExtendedMetadata {
        return FileMetadataExtractor.extractExtendedMetadata(from: url)
    }
    
    // MARK: - Write Metadata
    
    func saveMetadata(_ metadata: FileMetadata) -> Result<Void, Error> {
        let url = metadata.url
        
        do {
            var attributes: [FileAttributeKey: Any] = [:]
            
            // Update modification date if changed
            if let modDate = metadata.modificationDate {
                attributes[.modificationDate] = modDate
            }
            
            // Update creation date if changed
            if let creationDate = metadata.creationDate {
                try setCreationDate(url: url, date: creationDate)
            }
            
            // Set standard attributes
            if !attributes.isEmpty {
                try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
            }
            
            // Write MTData tracking fields
            writeExtendedAttribute(url: url, key: editedByKey, value: "MTData for macOS".data(using: .utf8)!)
            writeExtendedAttribute(url: url, key: versionKey, value: mtdataVersion.data(using: .utf8)!)
            let editDate = ISO8601DateFormatter().string(from: Date())
            writeExtendedAttribute(url: url, key: lastEditKey, value: editDate.data(using: .utf8)!)
            
            // Write custom fields
            saveCustomFields(metadata.customFields, to: url)
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    private func setCreationDate(url: URL, date: Date) throws {
        var resourceValues = URLResourceValues()
        resourceValues.creationDate = date
        var mutableURL = url
        
        do {
            try mutableURL.setResourceValues(resourceValues)
        } catch {
            // If setting via URL resource values fails, try alternative method
            let attributes: [FileAttributeKey: Any] = [.creationDate: date]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        }
    }
    
    // MARK: - Custom Fields
    
    private func readCustomFields(from url: URL) -> [CustomField] {
        guard let data = readExtendedAttribute(url: url, key: customFieldsKey) else {
            return []
        }
        
        do {
            let fields = try JSONDecoder().decode([CustomField].self, from: data)
            return fields
        } catch {
            print("Error decoding custom fields: \(error)")
            return []
        }
    }
    
    private func saveCustomFields(_ fields: [CustomField], to url: URL) {
        do {
            let data = try JSONEncoder().encode(fields)
            writeExtendedAttribute(url: url, key: customFieldsKey, value: data)
        } catch {
            print("Error encoding custom fields: \(error)")
        }
    }
    
    // MARK: - Extended Attributes (xattr)
    
    private func readExtendedAttribute(url: URL, key: String) -> Data? {
        let path = url.path
        
        // Get size of attribute
        let size = getxattr(path, key, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        
        // Read attribute
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { pointer in
            getxattr(path, key, pointer.baseAddress, size, 0, 0)
        }
        
        guard result >= 0 else { return nil }
        return data
    }
    
    private func writeExtendedAttribute(url: URL, key: String, value: Data) {
        let path = url.path
        _ = value.withUnsafeBytes { pointer in
            setxattr(path, key, pointer.baseAddress, value.count, 0, 0)
        }
    }
    
    func removeExtendedAttribute(url: URL, key: String) {
        let path = url.path
        removexattr(path, key, 0)
    }
    
    // MARK: - System Metadata Management
    
    func readAllExtendedAttributes(from url: URL) -> [String: String] {
        var allAttrs: [String: String] = [:]
        let path = url.path
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
        
        return allAttrs
    }
    
    func readFinderTags(from url: URL) -> [String] {
        if let tags = try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames {
            return tags
        }
        return []
    }
    
    func readQuarantineInfo(from url: URL) -> QuarantineInfo? {
        guard let quarantineData = readExtendedAttribute(url: url, key: "com.apple.quarantine"),
              let quarantineString = String(data: quarantineData, encoding: .utf8) else {
            return nil
        }
        
        // Quarantine format: flags;timestamp;agent;UUID or URL
        let components = quarantineString.components(separatedBy: ";")
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
    
    func readWhereFromURLs(from url: URL) -> [String]? {
        guard let whereFromData = readExtendedAttribute(url: url, key: "com.apple.metadata:kMDItemWhereFroms") else {
            return nil
        }
        
        // This is a binary plist
        do {
            if let plist = try PropertyListSerialization.propertyList(from: whereFromData, format: nil) as? [String] {
                return plist.filter { !$0.isEmpty }
            }
        } catch {
            // Try as string
            if let string = String(data: whereFromData, encoding: .utf8) {
                return [string]
            }
        }
        return nil
    }
    
    func removeQuarantineAttribute(from url: URL) -> Result<Void, Error> {
        removeExtendedAttribute(url: url, key: "com.apple.quarantine")
        return .success(())
    }
    
    func updateFinderTags(url: URL, tags: [String]) -> Result<Void, Error> {
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.tagNames = tags
        
        do {
            try mutableURL.setResourceValues(resourceValues)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func updateFinderComment(url: URL, comment: String) -> Result<Void, Error> {
        // Finder comments are stored in the extended attribute
        let data = comment.data(using: .utf8) ?? Data()
        writeExtendedAttribute(url: url, key: "com.apple.metadata:kMDItemFinderComment", value: data)
        return .success(())
    }
    
    func updateWhereFromURLs(url: URL, urls: [String]) -> Result<Void, Error> {
        if urls.isEmpty {
            // Remove the attribute entirely if no URLs
            removeExtendedAttribute(url: url, key: "com.apple.metadata:kMDItemWhereFroms")
            return .success(())
        }
        
        // Encode as binary plist
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: urls, format: .binary, options: 0)
            writeExtendedAttribute(url: url, key: "com.apple.metadata:kMDItemWhereFroms", value: data)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Remove All Metadata
    
    func removeAllMTDataMetadata(from url: URL) -> Result<Void, Error> {
        // Remove MTData tracking attributes
        removeExtendedAttribute(url: url, key: editedByKey)
        removeExtendedAttribute(url: url, key: versionKey)
        removeExtendedAttribute(url: url, key: lastEditKey)
        
        // Remove custom fields
        removeExtendedAttribute(url: url, key: customFieldsKey)
        
        // List all extended attributes and remove any com.mtdata.* ones
        let path = url.path
        let bufferSize = listxattr(path, nil, 0, 0)
        if bufferSize > 0 {
            var buffer = [CChar](repeating: 0, count: bufferSize)
            listxattr(path, &buffer, bufferSize, 0)
            
            let attributeNames = String(cString: buffer).components(separatedBy: "\0")
            for attrName in attributeNames where attrName.hasPrefix("com.mtdata.") {
                removeExtendedAttribute(url: url, key: attrName)
            }
        }
        
        return .success(())
    }
}

