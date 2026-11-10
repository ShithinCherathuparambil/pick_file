import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../exceptions/pick_file_exception.dart';
import '../models/picked_file.dart';
import '../options/file_pick_options.dart';
import '../platform/messages.g.dart';

/// The entry point for the pick_file plugin.
///
/// Provides straightforward, static methods to pick single or multiple files
/// with type-safe filtering, size limits, and lazy file access.
class PickFile {
  PickFile._();

  static PickFileHostApi _hostApi = PickFileHostApi();

  /// Overrides the [PickFileHostApi] instance. Intended for unit testing.
  @visibleForTesting
  static void setMockHostApi(PickFileHostApi? api) {
    _hostApi = api ?? PickFileHostApi();
  }

  /// Picks a single file according to the provided [options].
  ///
  /// Returns `null` if the user cancels the picker without selecting a file.
  /// Throws a typed [PickFileException] if selection or copying fails.
  static Future<PickedFile?> single({FilePickOptions? options}) async {
    final effectiveOptions = (options ?? const FilePickOptions()).copyWith(
      allowMultiple: false,
    );
    final results = await _pickInternal(effectiveOptions);
    return results.isEmpty ? null : results.first;
  }

  /// Picks multiple files according to the provided [options].
  ///
  /// Returns an empty list `[]` if the user cancels the picker.
  /// Throws a typed [PickFileException] if selection or copying fails.
  static Future<List<PickedFile>> multiple({FilePickOptions? options}) async {
    final effectiveOptions = (options ?? const FilePickOptions()).copyWith(
      allowMultiple: true,
    );
    return _pickInternal(effectiveOptions);
  }

  /// Picks standard document files (PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, TXT, CSV, JSON, etc.).
  ///
  /// Set [allowMultiple] to `true` to select more than one document.
  /// Returns `null` if single pick is cancelled, or a single [PickedFile].
  static Future<PickedFile?> documents({
    bool allowMultiple = false,
    int? maxFiles,
    int? maxSizeBytes,
    List<String>? extensions,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.documents,
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
      extensions: extensions,
    );
    final results = await _pickInternal(options);
    return results.isEmpty ? null : results.first;
  }

  /// Picks standard document files allowing multiple selection.
  ///
  /// Returns an empty list if user cancels.
  static Future<List<PickedFile>> documentsMultiple({
    int? maxFiles,
    int? maxSizeBytes,
    List<String>? extensions,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.documents,
      allowMultiple: true,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
      extensions: extensions,
    );
    return _pickInternal(options);
  }

  /// Picks image files (JPEG, PNG, GIF, WebP, HEIC, etc.) as ordinary documents.
  static Future<PickedFile?> images({
    bool allowMultiple = false,
    int? maxFiles,
    int? maxSizeBytes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.images,
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    final results = await _pickInternal(options);
    return results.isEmpty ? null : results.first;
  }

  /// Picks image files allowing multiple selection.
  static Future<List<PickedFile>> imagesMultiple({
    int? maxFiles,
    int? maxSizeBytes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.images,
      allowMultiple: true,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    return _pickInternal(options);
  }

  /// Picks video files (MP4, MOV, AVI, MKV, WebM, etc.).
  static Future<PickedFile?> videos({
    bool allowMultiple = false,
    int? maxFiles,
    int? maxSizeBytes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.videos,
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    final results = await _pickInternal(options);
    return results.isEmpty ? null : results.first;
  }

  /// Picks audio files (MP3, WAV, AAC, M4A, FLAC, etc.).
  static Future<PickedFile?> audio({
    bool allowMultiple = false,
    int? maxFiles,
    int? maxSizeBytes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.audio,
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    final results = await _pickInternal(options);
    return results.isEmpty ? null : results.first;
  }

  /// Picks compressed archive files (ZIP, RAR, 7Z, TAR, GZ, etc.).
  static Future<PickedFile?> archives({
    bool allowMultiple = false,
    int? maxFiles,
    int? maxSizeBytes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.archives,
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    final results = await _pickInternal(options);
    return results.isEmpty ? null : results.first;
  }

  /// Picks files matching custom extensions (e.g. `['pdf', 'docx', 'csv']`)
  /// and optional [mimeTypes].
  static Future<PickedFile?> custom({
    required List<String> extensions,
    bool allowMultiple = false,
    int? maxFiles,
    int? maxSizeBytes,
    List<String>? mimeTypes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.custom,
      extensions: extensions,
      mimeTypes: mimeTypes,
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    final results = await _pickInternal(options);
    return results.isEmpty ? null : results.first;
  }

  /// Picks multiple files matching custom extensions.
  static Future<List<PickedFile>> customMultiple({
    required List<String> extensions,
    int? maxFiles,
    int? maxSizeBytes,
    List<String>? mimeTypes,
  }) async {
    final options = FilePickOptions(
      type: FileTypeFilter.custom,
      extensions: extensions,
      mimeTypes: mimeTypes,
      allowMultiple: true,
      maxFiles: maxFiles,
      maxSizeBytes: maxSizeBytes,
    );
    return _pickInternal(options);
  }

  /// Clears temporary cached files created by this plugin.
  ///
  /// Does not delete files currently being processed or files saved to external
  /// directories via [PickedFile.saveTo].
  static Future<void> clearCache() async {
    try {
      await _hostApi.clearCache();
    } on PlatformException catch (e) {
      throw PickFileException.fromPlatformException(e);
    } catch (e, stack) {
      throw NativePickerFailedException(
        message: 'Failed to clear cache: $e',
        details: stack.toString(),
      );
    }
  }

  // --- Internal implementation ---

  static Future<List<PickedFile>> _pickInternal(FilePickOptions options) async {
    options.validate();

    final dto = FilePickOptionsDto(
      allowMultiple: options.allowMultiple,
      maxFiles: options.maxFiles,
      maxSizeBytes: options.maxSizeBytes,
      allowedExtensions: options.normalizedExtensions,
      allowedMimeTypes: options.normalizedMimeTypes,
      filterType: options.type.name,
    );

    final List<PickedFileResult?> rawResults;
    try {
      rawResults = await _hostApi.pickFiles(dto);
    } on PlatformException catch (e) {
      throw PickFileException.fromPlatformException(e);
    } catch (e, stack) {
      throw NativePickerFailedException(
        message: 'Platform call failed: $e',
        details: stack.toString(),
      );
    }

    final validResults = rawResults.whereType<PickedFileResult>().toList();

    // Secondary validation in Dart layer (all-or-error guarantee)
    if (options.maxFiles != null && validResults.length > options.maxFiles!) {
      throw MaximumFileCountExceededException(
        message:
            'Selected ${validResults.length} files exceeds maximum allowed count of ${options.maxFiles}.',
      );
    }

    final pickedFiles = <PickedFile>[];
    final allowedExts = options.normalizedExtensions;

    for (final item in validResults) {
      if (options.maxSizeBytes != null &&
          item.sizeBytes > options.maxSizeBytes!) {
        throw MaximumSizeExceededException(
          message:
              'File "${item.name}" size (${item.sizeBytes} bytes) exceeds maximum limit (${options.maxSizeBytes} bytes).',
        );
      }

      if (allowedExts != null && allowedExts.isNotEmpty) {
        final cleanExt = item.fileExtension.trim().toLowerCase();
        if (!allowedExts.contains(cleanExt)) {
          throw UnsupportedFileTypeException(
            message:
                'File "${item.name}" with extension ".$cleanExt" is not in allowed list: $allowedExts.',
          );
        }
      }

      pickedFiles.add(
        PickedFile(
          name: item.name,
          path: item.path,
          extension: item.fileExtension.toLowerCase(),
          mimeType: item.mimeType,
          sizeBytes: item.sizeBytes,
        ),
      );
    }

    return pickedFiles;
  }
}
