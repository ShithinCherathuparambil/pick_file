import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pick_file/pick_file.dart';

void main() {
  group('PickFileException factory and subclasses', () {
    test('maps all 14 error codes from PlatformException correctly', () {
      final codeMap = {
        'picker_busy': isA<PickerBusyException>(),
        'invalid_filter': isA<InvalidFilterException>(),
        'invalid_options': isA<InvalidOptionsException>(),
        'file_not_found': isA<FileNotFoundException>(),
        'provider_unavailable': isA<ProviderUnavailableException>(),
        'unsupported_file_type': isA<UnsupportedFileTypeException>(),
        'maximum_size_exceeded': isA<MaximumSizeExceededException>(),
        'maximum_file_count_exceeded': isA<MaximumFileCountExceededException>(),
        'file_access_denied': isA<FileAccessDeniedException>(),
        'file_copy_failed': isA<FileCopyFailedException>(),
        'insufficient_storage': isA<InsufficientStorageException>(),
        'file_read_failed': isA<FileReadFailedException>(),
        'platform_unavailable': isA<PlatformUnavailableException>(),
        'native_picker_failed': isA<NativePickerFailedException>(),
        'unknown_random_error': isA<NativePickerFailedException>(),
      };

      for (final entry in codeMap.entries) {
        final platformException = PlatformException(
          code: entry.key,
          message: 'Error message for ${entry.key}',
          details: {'info': 123},
        );

        final ex = PickFileException.fromPlatformException(platformException);
        expect(ex, entry.value);
        expect(ex.code, entry.key);
        expect(ex.message, 'Error message for ${entry.key}');
        expect(ex.details, {'info': 123});
        expect(ex.toString(), contains(entry.key));
      }
    });

    test('toString formats details correctly', () {
      const withDetails = PickerBusyException(
        message: 'Busy',
        details: 'Extra',
      );
      expect(withDetails.toString(), contains('details: Extra'));

      const withoutDetails = PickerBusyException(message: 'Busy');
      expect(withoutDetails.toString(), isNot(contains('details:')));
    });
  });
}

