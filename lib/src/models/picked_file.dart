import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import '../exceptions/pick_file_exception.dart';

/// Represents a file picked by the user and made accessible locally in the application cache.
///
/// File reading remains strictly lazy; no file content is loaded into memory until
/// [readAsBytes] or [openRead] is called.
@immutable
class PickedFile {
  /// Creates a [PickedFile] instance.
  const PickedFile({
    required this.name,
    required this.path,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
  });

  /// The original or sanitized display name of the file including extension (e.g. `report.pdf`).
  final String name;

  /// The local filesystem path to the plugin-managed cached copy of the file.
  final String path;

  /// The lowercase file extension without a leading dot (e.g. `pdf`, `docx`, `png`).
  final String extension;

  /// The detected or provider-reported MIME type of the file (e.g. `application/pdf`).
  final String mimeType;

  /// The size of the file in bytes.
  final int sizeBytes;

  /// Returns a [File] handle pointing to the local cached copy.
  File get file => File(path);

  /// Lazily reads the full contents of the file as bytes.
  ///
  /// For very large files, consider using [openRead] instead to stream chunks.
  /// Throws [FileReadFailedException] if reading fails or file is missing.
  Future<Uint8List> readAsBytes() async {
    try {
      final f = file;
      if (!await f.exists()) {
        throw FileNotFoundException(
          message: 'Cached file not found at path: $path',
        );
      }
      return await f.readAsBytes();
    } on PickFileException {
      rethrow;
    } catch (e, stack) {
      throw FileReadFailedException(
        message: 'Failed to read file bytes: $e',
        details: stack.toString(),
      );
    }
  }

  /// Lazily opens a stream to read the file chunk by chunk.
  ///
  /// Safe for multi-gigabyte files as it does not buffer the entire file in RAM.
  Stream<List<int>> openRead([int? start, int? end]) {
    try {
      return file.openRead(start, end);
    } catch (e, stack) {
      throw FileReadFailedException(
        message: 'Failed to open file stream: $e',
        details: stack.toString(),
      );
    }
  }

  /// Copies this file to a persistent destination path outside the plugin's temporary cache.
  ///
  /// Automatically creates any missing parent directories.
  /// Returns the newly written [File].
  ///
  /// Throws [FileCopyFailedException] or [FileNotFoundException] if the operation fails.
  Future<File> saveTo(String destinationPath) async {
    try {
      final source = file;
      if (!await source.exists()) {
        throw FileNotFoundException(
          message: 'Cannot save missing file: $path',
        );
      }

      final destination = File(destinationPath);
      final parentDir = destination.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Stream the copy in bounded chunks to avoid loading whole file in memory
      final inputStream = source.openRead();
      final outputSink = destination.openWrite();
      await inputStream.pipe(outputSink);

      return destination;
    } on PickFileException {
      rethrow;
    } catch (e, stack) {
      throw FileCopyFailedException(
        message: 'Failed to save file to "$destinationPath": $e',
        details: stack.toString(),
      );
    }
  }

  /// Returns a human-readable formatted string representing file size (e.g. `512 B`, `2.4 MB`).
  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PickedFile &&
        other.path == path &&
        other.name == name &&
        other.extension == extension &&
        other.mimeType == mimeType &&
        other.sizeBytes == sizeBytes;
  }

  @override
  int get hashCode => Object.hash(path, name, extension, mimeType, sizeBytes);

  @override
  String toString() {
    return 'PickedFile(name: $name, path: $path, size: $sizeFormatted, mime: $mimeType)';
  }
}
