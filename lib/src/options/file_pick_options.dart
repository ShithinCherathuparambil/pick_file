import 'package:meta/meta.dart';

import '../exceptions/pick_file_exception.dart';

/// Predefined file category filters for [FilePickOptions].
enum FileTypeFilter {
  /// Any file type supported by the operating system.
  any,

  /// Image files (JPEG, PNG, GIF, WebP, HEIC, etc.).
  images,

  /// Video files (MP4, MOV, AVI, MKV, WebM, etc.).
  videos,

  /// Audio files (MP3, WAV, AAC, M4A, FLAC, etc.).
  audio,

  /// Standard document formats (PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, TXT, CSV, JSON, etc.).
  documents,

  /// Compressed archive files (ZIP, RAR, 7Z, TAR, GZ, etc.).
  archives,

  /// User-defined custom extensions or MIME types.
  custom,
}

/// Configuration options for file selection.
@immutable
class FilePickOptions {
  /// Creates a configuration object for file picking.
  const FilePickOptions({
    this.type = FileTypeFilter.any,
    this.allowMultiple = false,
    this.maxFiles,
    this.maxSizeBytes,
    this.extensions,
    this.mimeTypes,
  });

  /// The preset category of files to allow. Defaults to [FileTypeFilter.any].
  final FileTypeFilter type;

  /// Whether multiple files may be selected at once. Defaults to `false`.
  final bool allowMultiple;

  /// The maximum number of files that may be selected.
  ///
  /// Only applies when [allowMultiple] is true. Must be greater than 0 if provided.
  final int? maxFiles;

  /// The maximum allowed size for each selected file in bytes.
  ///
  /// Must be greater than 0 if provided.
  final int? maxSizeBytes;

  /// Allowed file extensions without leading dots (e.g., `['pdf', 'docx']`).
  ///
  /// Case-insensitive. Required when [type] is [FileTypeFilter.custom] unless
  /// [mimeTypes] is provided.
  final List<String>? extensions;

  /// Allowed MIME types (e.g., `['application/pdf', 'image/*']`).
  ///
  /// Case-insensitive. Optional complement to [extensions].
  final List<String>? mimeTypes;

  /// Normalizes and validates the options.
  ///
  /// Throws [InvalidOptionsException] or [InvalidFilterException] on invalid input.
  void validate() {
    if (maxFiles != null && maxFiles! <= 0) {
      throw const InvalidOptionsException(
        message: 'maxFiles must be greater than 0 if specified.',
      );
    }

    if (!allowMultiple && maxFiles != null && maxFiles! > 1) {
      throw const InvalidOptionsException(
        message:
            'maxFiles cannot be greater than 1 when allowMultiple is false.',
      );
    }

    if (maxSizeBytes != null && maxSizeBytes! <= 0) {
      throw const InvalidOptionsException(
        message: 'maxSizeBytes must be greater than 0 if specified.',
      );
    }

    if (type == FileTypeFilter.custom) {
      final hasExtensions = extensions != null && extensions!.isNotEmpty;
      final hasMimeTypes = mimeTypes != null && mimeTypes!.isNotEmpty;
      if (!hasExtensions && !hasMimeTypes) {
        throw const InvalidFilterException(
          message: 'FileTypeFilter.custom requires at least one extension or MIME type.',
        );
      }
    }

    if (extensions != null) {
      for (final ext in extensions!) {
        final clean = ext.trim().replaceAll(RegExp(r'^\.+'), '');
        if (clean.isEmpty || clean.contains('/') || clean.contains(r'\')) {
          throw InvalidFilterException(
            message: 'Invalid extension format: "$ext".',
          );
        }
      }
    }

    if (mimeTypes != null) {
      for (final mime in mimeTypes!) {
        final clean = mime.trim();
        if (clean.isEmpty || !clean.contains('/')) {
          throw InvalidFilterException(
            message: 'Invalid MIME type format: "$mime". Must contain "/".',
          );
        }
      }
    }
  }

  /// Returns cleaned, lowercased extensions without leading dots.
  List<String>? get normalizedExtensions {
    if (extensions == null) return null;
    return extensions!
        .map((e) => e.trim().toLowerCase().replaceAll(RegExp(r'^\.+'), ''))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Returns cleaned, lowercased MIME types.
  List<String>? get normalizedMimeTypes {
    if (mimeTypes == null) return null;
    return mimeTypes!
        .map((m) => m.trim().toLowerCase())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);
  }

  /// Creates a copy of this [FilePickOptions] with given fields replaced.
  FilePickOptions copyWith({
    FileTypeFilter? type,
    bool? allowMultiple,
    int? maxFiles,
    int? maxSizeBytes,
    List<String>? extensions,
    List<String>? mimeTypes,
  }) {
    return FilePickOptions(
      type: type ?? this.type,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      maxFiles: maxFiles ?? this.maxFiles,
      maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
      extensions: extensions ?? this.extensions,
      mimeTypes: mimeTypes ?? this.mimeTypes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilePickOptions &&
        other.type == type &&
        other.allowMultiple == allowMultiple &&
        other.maxFiles == maxFiles &&
        other.maxSizeBytes == maxSizeBytes &&
        _listEquals(other.extensions, extensions) &&
        _listEquals(other.mimeTypes, mimeTypes);
  }

  @override
  int get hashCode => Object.hash(
    type,
    allowMultiple,
    maxFiles,
    maxSizeBytes,
    Object.hashAll(extensions ?? const []),
    Object.hashAll(mimeTypes ?? const []),
  );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
