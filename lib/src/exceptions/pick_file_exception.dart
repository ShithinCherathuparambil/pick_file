import 'package:flutter/services.dart';

/// Base class for all exceptions thrown by the pick_file plugin.
sealed class PickFileException implements Exception {
  const PickFileException({
    required this.code,
    required this.message,
    this.details,
  });

  /// The machine-readable error code.
  final String code;

  /// A human-readable description of the error.
  final String message;

  /// Additional diagnostic details, if available.
  final dynamic details;

  /// Factory constructor to convert any [PlatformException] or error code into
  /// a specific typed [PickFileException] subclass.
  factory PickFileException.fromPlatformException(PlatformException exception) {
    return PickFileException.fromCode(
      exception.code,
      message: exception.message,
      details: exception.details,
    );
  }

  /// Factory constructor to create a typed [PickFileException] by code.
  factory PickFileException.fromCode(
    String code, {
    String? message,
    dynamic details,
  }) {
    final msg = message ?? 'An error occurred in pick_file: $code';
    switch (code) {
      case 'picker_busy':
        return PickerBusyException(message: msg, details: details);
      case 'invalid_filter':
        return InvalidFilterException(message: msg, details: details);
      case 'invalid_options':
        return InvalidOptionsException(message: msg, details: details);
      case 'file_not_found':
        return FileNotFoundException(message: msg, details: details);
      case 'provider_unavailable':
        return ProviderUnavailableException(message: msg, details: details);
      case 'unsupported_file_type':
        return UnsupportedFileTypeException(message: msg, details: details);
      case 'maximum_size_exceeded':
        return MaximumSizeExceededException(message: msg, details: details);
      case 'maximum_file_count_exceeded':
        return MaximumFileCountExceededException(
          message: msg,
          details: details,
        );
      case 'file_access_denied':
        return FileAccessDeniedException(message: msg, details: details);
      case 'file_copy_failed':
        return FileCopyFailedException(message: msg, details: details);
      case 'insufficient_storage':
        return InsufficientStorageException(message: msg, details: details);
      case 'file_read_failed':
        return FileReadFailedException(message: msg, details: details);
      case 'platform_unavailable':
        return PlatformUnavailableException(message: msg, details: details);
      case 'native_picker_failed':
      default:
        return NativePickerFailedException(
          code: code,
          message: msg,
          details: details,
        );
    }
  }

  @override
  String toString() {
    if (details != null) {
      return '$runtimeType(code: $code, message: $message, details: $details)';
    }
    return '$runtimeType(code: $code, message: $message)';
  }
}

/// Thrown when another file picker operation is already in progress.
class PickerBusyException extends PickFileException {
  const PickerBusyException({required super.message, super.details})
    : super(code: 'picker_busy');
}

/// Thrown when an invalid or malformed file filter (extension or MIME) is provided.
class InvalidFilterException extends PickFileException {
  const InvalidFilterException({required super.message, super.details})
    : super(code: 'invalid_filter');
}

/// Thrown when conflicting or invalid pick options are specified.
class InvalidOptionsException extends PickFileException {
  const InvalidOptionsException({required super.message, super.details})
    : super(code: 'invalid_options');
}

/// Thrown when the selected file cannot be located on the filesystem or provider.
class FileNotFoundException extends PickFileException {
  const FileNotFoundException({required super.message, super.details})
    : super(code: 'file_not_found');
}

/// Thrown when the external storage provider or cloud service is unreachable.
class ProviderUnavailableException extends PickFileException {
  const ProviderUnavailableException({required super.message, super.details})
    : super(code: 'provider_unavailable');
}

/// Thrown when the user selects a file with a type or extension not permitted by filters.
class UnsupportedFileTypeException extends PickFileException {
  const UnsupportedFileTypeException({required super.message, super.details})
    : super(code: 'unsupported_file_type');
}

/// Thrown when a selected file exceeds the configured maximum allowed file size.
class MaximumSizeExceededException extends PickFileException {
  const MaximumSizeExceededException({required super.message, super.details})
    : super(code: 'maximum_size_exceeded');
}

/// Thrown when the count of selected files exceeds the configured maximum.
class MaximumFileCountExceededException extends PickFileException {
  const MaximumFileCountExceededException({
    required super.message,
    super.details,
  }) : super(code: 'maximum_file_count_exceeded');
}

/// Thrown when permission to access the file or security-scoped resource is denied.
class FileAccessDeniedException extends PickFileException {
  const FileAccessDeniedException({required super.message, super.details})
    : super(code: 'file_access_denied');
}

/// Thrown when copying the selected file into the app cache fails.
class FileCopyFailedException extends PickFileException {
  const FileCopyFailedException({required super.message, super.details})
    : super(code: 'file_copy_failed');
}

/// Thrown when device storage is insufficient to copy the selected file.
class InsufficientStorageException extends PickFileException {
  const InsufficientStorageException({required super.message, super.details})
    : super(code: 'insufficient_storage');
}

/// Thrown when an error occurs while reading the file content from the provider.
class FileReadFailedException extends PickFileException {
  const FileReadFailedException({required super.message, super.details})
    : super(code: 'file_read_failed');
}

/// Thrown when the host platform activity, window, or engine is unavailable.
class PlatformUnavailableException extends PickFileException {
  const PlatformUnavailableException({required super.message, super.details})
    : super(code: 'platform_unavailable');
}

/// Thrown when an unclassified native picker failure occurs.
class NativePickerFailedException extends PickFileException {
  const NativePickerFailedException({
    super.code = 'native_picker_failed',
    required super.message,
    super.details,
  });
}
