# MTData - Metadata Editor for macOS

MTData is a powerful and easy-to-use macOS application that allows you to view and edit file metadata. Inspired by the clean design of Keka, MTData provides a simple interface for managing both system metadata and custom fields.

## Features

### 1. Open Any File Format
- Select files using the file picker or drag and drop
- Works with any file type on macOS
- Displays file icon, name, type, and size

### 2. View and Edit System Metadata
- **Creation Date**: View and modify when the file was created
- **Modification Date**: View and modify when the file was last changed
- **File Size**: Display file size in human-readable format
- **File Type**: Show the UTI (Uniform Type Identifier)
- **Permissions**: View POSIX permissions

### 3. System & Extended Attributes (NEW in v2.0)
- **Quarantine Information**: View and remove macOS quarantine flags ("downloaded from" warnings)
- **Download Sources**: Display URLs where files were downloaded from
- **Finder Tags**: View file tags and colors
- **Spotlight Comments**: Display Finder comments
- **Extended Attributes**: View all extended file attributes (xattr)

### 4. Comprehensive File Format Support (NEW in v2.0)

#### Images (JPEG, PNG, TIFF, HEIC, RAW)
- **EXIF**: Camera make/model, lens, focal length, aperture, ISO, shutter speed, serial number, date taken
- **GPS**: Latitude, longitude, altitude with proper formatting
- **Advanced EXIF**: Orientation, exposure compensation, white balance, metering mode
- **IPTC**: Keywords, caption, credits, copyright, byline
- **XMP**: Rating, creator tool
- **PNG**: Software, creation time, text chunks (tEXt/iTXt)
- **HEIC**: Live photo pairing ID

#### Audio Files (MP3, M4A, FLAC, WAV, AIFF)
- **ID3v2/iTunes**: Title, artist, album, composer, track number, year, genre, comments
- **Album Art**: Detection of embedded artwork
- **Technical**: Duration, bitrate, codec information
- **Vorbis Comments**: Support for OGG and FLAC metadata

#### Video Files (MP4, MOV, MKV, AVI)
- **Basic Info**: Title, resolution, frame rate, duration
- **Codecs**: Video and audio codec information
- **Tracks**: Audio track count and languages, subtitle track count and languages
- **Container**: Format type (MP4, MOV, MKV, etc.)
- **Location**: GPS location data for videos
- **Creation Date**: Original recording date and time

#### PDF Documents
- **Document Info**: Title, author, subject, keywords, producer
- **Technical**: Page count, PDF version, encryption status
- **Dates**: Creation and modification timestamps

#### Office Documents (DOCX, XLSX, PPTX)
- **Core Properties**: Title, subject, creator, last modified by
- **Dates**: Creation and modification times
- **Application**: Generating application name, revision number
- **ePub**: Title, creator, language, publisher, identifier

#### Text Files (TXT, MD, Source Code)
- **Encoding**: Automatic detection (UTF-8, UTF-16, ASCII, ISO-8859-1)
- **BOM**: Byte Order Mark presence detection
- **Line Endings**: CRLF (Windows), LF (Unix), or CR (Classic Mac)
- **Front Matter**: YAML/TOML metadata extraction for Markdown files

#### Archives (ZIP, TAR)
- **Format**: Archive type identification
- **Contents**: File count
- **Compression**: Method and total size information

#### Executables (macOS Binaries)
- **Type**: Mach-O identification (32-bit, 64-bit, Universal Binary)
- **Architectures**: x86_64, ARM64 (Apple Silicon), etc.
- **Code Signing**: Signature verification status
- **Multi-architecture**: Fat binary analysis with architecture listing

### 5. MTData Tracking
When you edit metadata with MTData, the following information is automatically added:
- **Edited by MTData for macOS**: Indicates the file has been modified by MTData
- **MTData Version**: Records which version of MTData was used
- **Last Edit Date**: Timestamp of the most recent edit

### 6. Custom MTData Fields
- Add unlimited custom key-value pairs to any file
- Edit and delete custom fields as needed
- Data is stored in extended attributes (xattr) using the `com.mtdata.*` namespace
- Custom fields are preserved with the file and viewable by any MTData installation

### 7. Clean, Modern Interface
- Keka-inspired minimal design
- Organized sections for different metadata types
- Collapsible sections for clean viewing
- Easy-to-use date pickers for temporal data
- Revert button to undo changes before saving
- Success/error alerts for save operations
- Copy-enabled text fields for easy data extraction

## Technical Details

### Storage Method
MTData uses macOS extended attributes (xattr) to store custom metadata and tracking information:
- `com.mtdata.customfields` - JSON-encoded custom field data
- `com.mtdata.editedby` - Editor identification
- `com.mtdata.version` - MTData version number
- `com.mtdata.lastedit` - ISO8601 timestamp of last edit

### System Requirements
- macOS 14.0 or later
- File system with extended attributes support (HFS+, APFS)

### Permissions
MTData uses macOS sandbox entitlements:
- `com.apple.security.files.user-selected.read-write` - Allows reading and writing files selected by the user

## Usage

1. **Launch MTData**
   - Open the application
   - You'll see the file picker screen

2. **Select a File**
   - Click "Select File" button, or
   - Drag and drop a file onto the window

3. **View Metadata**
   - System metadata is displayed in the first section
   - MTData tracking info appears if the file was previously edited
   - Custom fields are shown at the bottom

4. **Edit Metadata**
   - Use date/time pickers to change creation or modification dates
   - Add custom fields using the "+" button
   - Edit custom field values directly in the text fields
   - Delete custom fields with the trash icon

5. **Save Changes**
   - Click "Save Changes" to apply modifications
   - Click "Revert" to discard unsaved changes
   - An alert will confirm successful save or report errors

6. **Close File**
   - Click the "×" button in the header to return to the file picker

## Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd mtdata

# Open in Xcode
open mtdata.xcodeproj

# Build and run
# Product > Run (⌘R)
```

## License

Copyright © 2025 MTData. All rights reserved.

## Version History

**v2.0** - Major Update: Comprehensive Metadata Support (October 2025)
- **System Attributes**: Quarantine flag viewing/removal, download source URLs, Finder tags, Spotlight comments
- **Enhanced Image Support**: EXIF (orientation, exposure, white balance, metering, serial numbers), IPTC (keywords, caption, credits, copyright), XMP (rating, creator), PNG text chunks, HEIC live photo pairing
- **Enhanced Audio Support**: Full ID3v2 tags, iTunes metadata atoms, album art detection, Vorbis comments, composer info
- **Enhanced Video Support**: Subtitle/audio track counts and languages, video location data, container format, separate video/audio codecs, creation dates
- **Document Support**: PDF (producer, encryption, dates), Office files (DOCX/XLSX/PPTX core properties, application info), ePub (OPF metadata)
- **Text File Analysis**: Encoding detection (UTF-8, UTF-16, ASCII, ISO-8859-1), BOM detection, line ending detection (CRLF/LF/CR), Markdown front matter extraction
- **Archive Support**: ZIP and TAR file count and format detection
- **Executable Analysis**: Mach-O binary detection, architecture identification (x86_64, ARM64), Universal Binary support, code signature verification
- **UI Improvements**: Organized metadata sections by file type, collapsible views, copy-enabled text fields, "Remove Quarantine" button

**v1.0** - Initial Release (October 2025)
- File metadata viewing and editing
- Custom field support
- Extended attributes storage
- Keka-inspired UI design

