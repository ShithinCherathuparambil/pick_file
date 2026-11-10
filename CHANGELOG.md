# Changelog

All notable changes to the `pick_file` package will be documented in this file.

## 0.0.1

- Initial release of `pick_file`.
- Implemented single and multiple file selection on Android via Storage Access Framework (`ACTION_OPEN_DOCUMENT`).
- Implemented single and multiple document picking on iOS using `UIDocumentPickerViewController` and `UniformTypeIdentifiers`.
- Stream-based copying to dedicated plugin cache to prevent high memory usage on large files.
- Added type filtering presets: `any`, `documents`, `images`, `videos`, `audio`, `archives`, and `custom`.
- Added extension and MIME type filtering with post-selection validation.
- Configurable `maxFiles` and `maxSizeBytes` constraints.
- Typed exception hierarchy for comprehensive error handling (`picker_busy`, `maximum_size_exceeded`, `file_access_denied`, etc.).
- Safe cache management API (`PickFile.clearCache()`).
- Interactive Material 3 example application demonstrating file selection, stream reading, and saving.
