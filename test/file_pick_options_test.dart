import 'package:flutter_test/flutter_test.dart';
import 'package:pick_file/pick_file.dart';

void main() {
  group('FilePickOptions', () {
    test('default values are set correctly', () {
      const options = FilePickOptions();
      expect(options.type, FileTypeFilter.any);
      expect(options.allowMultiple, false);
      expect(options.maxFiles, isNull);
      expect(options.maxSizeBytes, isNull);
      expect(options.extensions, isNull);
      expect(options.mimeTypes, isNull);
      expect(() => options.validate(), returnsNormally);
    });

    test('normalizes extensions and mime types', () {
      const options = FilePickOptions(
        type: FileTypeFilter.custom,
        extensions: [' .PDF ', 'DOCX', '..xlsx'],
        mimeTypes: [' Application/PDF ', 'IMAGE/PNG'],
      );
      expect(options.normalizedExtensions, ['pdf', 'docx', 'xlsx']);
      expect(options.normalizedMimeTypes, ['application/pdf', 'image/png']);
      expect(() => options.validate(), returnsNormally);
    });

    test('throws InvalidOptionsException when maxFiles <= 0', () {
      const options = FilePickOptions(maxFiles: 0);
      expect(() => options.validate(), throwsA(isA<InvalidOptionsException>()));
    });

    test('throws InvalidOptionsException when maxFiles > 1 and allowMultiple is false', () {
      const options = FilePickOptions(allowMultiple: false, maxFiles: 2);
      expect(() => options.validate(), throwsA(isA<InvalidOptionsException>()));
    });

    test('throws InvalidOptionsException when maxSizeBytes <= 0', () {
      const options = FilePickOptions(maxSizeBytes: -10);
      expect(() => options.validate(), throwsA(isA<InvalidOptionsException>()));
    });

    test('throws InvalidFilterException for FileTypeFilter.custom without extensions or mimeTypes', () {
      const options = FilePickOptions(type: FileTypeFilter.custom);
      expect(() => options.validate(), throwsA(isA<InvalidFilterException>()));
    });

    test('throws InvalidFilterException for malformed extensions', () {
      const options = FilePickOptions(
        type: FileTypeFilter.custom,
        extensions: ['pdf/doc'],
      );
      expect(() => options.validate(), throwsA(isA<InvalidFilterException>()));
    });

    test(
      'throws InvalidFilterException for malformed MIME types without slash',
      () {
        const options = FilePickOptions(
          type: FileTypeFilter.custom,
          mimeTypes: ['pdf'],
        );
        expect(
          () => options.validate(),
          throwsA(isA<InvalidFilterException>()),
        );
      },
    );

    test('copyWith updates properties correctly', () {
      const original = FilePickOptions(
        type: FileTypeFilter.any,
        allowMultiple: false,
      );
      final updated = original.copyWith(
        type: FileTypeFilter.documents,
        allowMultiple: true,
        maxFiles: 5,
        maxSizeBytes: 1024,
      );

      expect(updated.type, FileTypeFilter.documents);
      expect(updated.allowMultiple, true);
      expect(updated.maxFiles, 5);
      expect(updated.maxSizeBytes, 1024);
    });

    test('equality and hashCode work as expected', () {
      const opt1 = FilePickOptions(
        type: FileTypeFilter.custom,
        extensions: ['pdf', 'png'],
      );
      const opt2 = FilePickOptions(
        type: FileTypeFilter.custom,
        extensions: ['pdf', 'png'],
      );
      const opt3 = FilePickOptions(
        type: FileTypeFilter.custom,
        extensions: ['pdf', 'jpg'],
      );

      expect(opt1, equals(opt2));
      expect(opt1.hashCode, equals(opt2.hashCode));
      expect(opt1, isNot(equals(opt3)));
    });
  });
}
