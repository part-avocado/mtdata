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

### 3. MTData Tracking
When you edit metadata with MTData, the following information is automatically added:
- **Edited by MTData for macOS**: Indicates the file has been modified by MTData
- **MTData Version**: Records which version of MTData was used (currently v1.0)
- **Last Edit Date**: Timestamp of the most recent edit

### 4. Custom MTData Fields
- Add unlimited custom key-value pairs to any file
- Edit and delete custom fields as needed
- Data is stored in extended attributes (xattr) using the `com.mtdata.*` namespace
- Custom fields are preserved with the file and viewable by any MTData installation

### 5. Clean, Modern Interface
- Keka-inspired minimal design
- Organized sections for different metadata types
- Easy-to-use date pickers for temporal data
- Revert button to undo changes before saving
- Success/error alerts for save operations

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

**v1.0** - Initial Release
- File metadata viewing and editing
- Custom field support
- Extended attributes storage
- Keka-inspired UI design

