# pick_file

A production-ready, lightweight Flutter file picker plugin supporting native Storage Access Framework (SAF) on Android and `UIDocumentPickerViewController` on iOS.

Designed with clean architecture, Pigeon type-safe platform channels, bounded stream copying for large files, and zero third-party picker dependencies.

[![pub package](https://img.shields.io/pub/v/pick_file.svg)](https://pub.dev/packages/pick_file)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

---

## Features

- **Single & Multiple Selection**: Pick one file or batches with configurable constraints.
- **Modern Native APIs**:
  - **Android**: `Intent.ACTION_OPEN_DOCUMENT` with `CATEGORY_OPENABLE` and `ContentResolver` streaming. No legacy external storage APIs or broad permissions required.
  - **iOS**: `UIDocumentPickerViewController` with `UniformTypeIdentifiers`, security-scoped URL access, and coordinated file reading via `NSFileCoordinator`.
- **Type Filtering & Presets**: Built-in support for `any`, `documents`, `images`, `videos`, `audio`, `archives`, and `custom` extension / MIME filters.
- **Large File Streaming**: Copies files directly to an app-owned cache using a bounded 64 KB buffer to prevent memory spikes.
- **Size & Count Limits**: Enforce `maxSizeBytes` and `maxFiles` natively and in Dart.
- **Lazy File Access**: File bytes are never buffered in memory until explicitly requested via `readAsBytes()` or `openRead()`.
- **Cache Management**: Clean up temporary files safely using `PickFile.clearCache()`.
- **Typed Error Hierarchy**: Meaningful, predictable exceptions (`picker_busy`, `maximum_size_exceeded`, `file_access_denied`, etc.).
- **Graceful Cancellations**: Returns `null` for single cancellation and `[]` for multiple cancellation without throwing exceptions.

---

## Platform Support

| Platform | Minimum Version | Native Backend | Broad Storage Permission Required? |
| :--- | :--- | :--- | :--- |
| **Android** | API 23 (Android 6.0) | Storage Access Framework (SAF) | **No** |
| **iOS** | iOS 14.0+ | `UIDocumentPickerViewController` | **No** |

---

## Installation

Add `pick_file` to your `pubspec.yaml`:

```yaml
dependencies:
  pick_file: ^0.0.1
```

Then run:

```bash
flutter pub get
```

---

## Platform Setup

### Android

No additional permissions or manifest declarations are required for standard document selection. `ACTION_OPEN_DOCUMENT` grants read access to selected files through the system document picker.

Ensure your `minSdkVersion` in `android/app/build.gradle` is at least 23:

```groovy
android {
    defaultConfig {
        minSdkVersion 23
    }
}
```

### iOS

The plugin requires iOS 14.0 or later. If your app accesses documents stored in iCloud Drive, you may enable the **iCloud** capability with **iCloud Documents** checked in Xcode (`Signing & Capabilities`).

For local document selection, no special permissions are needed.

---

## Usage Examples

### 1. Pick a Single File

```dart
import 'package:pick_file/pick_file.dart';

final PickedFile? file = await PickFile.single();

if (file != null) {
  print('Name: ${file.name}');
  print('Path: ${file.path}');
  print('Size: ${file.sizeFormatted}');
  print('MIME: ${file.mimeType}');
} else {
  print('User cancelled selection');
}
```

### 2. Pick Multiple Files

```dart
final List<PickedFile> files = await PickFile.multiple();

for (final file in files) {
  print('${file.name} (${file.sizeFormatted})');
}
```

### 3. Pick PDF Documents

```dart
final PickedFile? pdf = await PickFile.documents(extensions: ['pdf']);
```

### 4. Pick with Custom Extensions

```dart
final PickedFile? file = await PickFile.custom(
  extensions: ['pdf', 'docx', 'xlsx', 'csv'],
);
```

### 5. Enforce Maximum Size and Count Limits

```dart
final List<PickedFile> files = await PickFile.multiple(
  options: const FilePickOptions(
    maxFiles: 3,
    maxSizeBytes: 10 * 1024 * 1024, // 10 MB limit per file
    type: FileTypeFilter.documents,
  ),
);
```

### 6. Streaming File Content (Large Files)

File reading remains lazy. Use `openRead()` to process multi-gigabyte files chunk-by-chunk without loading the whole file into RAM:

```dart
final PickedFile? file = await PickFile.single();
if (file != null) {
  await for (final chunk in file.openRead()) {
    // Process chunk (List<int>)
  }
}
```

### 7. Persist to App Storage

Files returned by the picker are located in the plugin's temporary cache directory. To persist a file, use `saveTo`:

```dart
final PickedFile? file = await PickFile.single();
if (file != null) {
  final File persistentFile = await file.saveTo('/path/to/app/documents/${file.name}');
  print('Persisted to: ${persistentFile.path}');
}
```

### 8. Clear Plugin Cache

```dart
await PickFile.clearCache();
```

---

## Temporary Cache vs. Persistent Storage

> [!NOTE]
> When a user selects a file from cloud storage, downloads, or external providers, the native plugin streams a local copy into the application's temporary cache (`pick_file` subfolder).
> 
> Temporary cached files may be removed by the operating system or when `PickFile.clearCache()` is called. If your application needs long-term access, copy the file using `file.saveTo(destinationPath)` to your app's permanent documents folder.

---

## Error Handling

`pick_file` provides typed exceptions mapped from platform error codes:

| Error Code | Exception Class | Description |
| :--- | :--- | :--- |
| `picker_busy` | `PickerBusyException` | Another file selection is already in progress. |
| `invalid_filter` | `InvalidFilterException` | Invalid or empty extension or MIME type specification. |
| `invalid_options` | `InvalidOptionsException` | Conflicting options (e.g., negative limits). |
| `file_not_found` | `FileNotFoundException` | The file could not be located. |
| `provider_unavailable` | `ProviderUnavailableException` | Cloud provider or file coordinator is unreachable. |
| `unsupported_file_type`| `UnsupportedFileTypeException` | Selected file does not match allowed types. |
| `maximum_size_exceeded`| `MaximumSizeExceededException` | Selected file exceeds `maxSizeBytes`. |
| `maximum_file_count_exceeded` | `MaximumFileCountExceededException` | Number of files exceeds `maxFiles`. |
| `file_access_denied` | `FileAccessDeniedException` | Permission to access security-scoped URL was denied. |
| `file_copy_failed` | `FileCopyFailedException` | Failed to write stream to local cache. |
| `insufficient_storage` | `InsufficientStorageException` | Device storage is full. |
| `file_read_failed` | `FileReadFailedException` | Reading from provider stream failed. |
| `platform_unavailable`| `PlatformUnavailableException` | Activity or view controller is not attached. |
| `native_picker_failed` | `NativePickerFailedException` | Unclassified native picker error. |

Example:

```dart
try {
  final file = await PickFile.single();
} on MaximumSizeExceededException catch (e) {
  print('File too large: ${e.message}');
} on PickerBusyException {
  print('Picker is already active');
} on PickFileException catch (e) {
  print('Picker error [${e.code}]: ${e.message}');
}
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
