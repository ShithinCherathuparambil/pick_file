import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pick_file/pick_file.dart';

void main() {
  group('PickedFile', () {
    late Directory tempDir;
    late File sampleFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('picked_file_test_');
      sampleFile = File('${tempDir.path}/test_doc.pdf');
      await sampleFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('model properties and formatting work correctly', () {
      final picked = PickedFile(
        name: 'test_doc.pdf',
        path: sampleFile.path,
        extension: 'pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
      );

      expect(picked.name, 'test_doc.pdf');
      expect(picked.path, sampleFile.path);
      expect(picked.extension, 'pdf');
      expect(picked.mimeType, 'application/pdf');
      expect(picked.sizeBytes, 5);
      expect(picked.sizeFormatted, '5 B');
      expect(picked.file.path, sampleFile.path);
    });

    test('sizeFormatted formats various scales correctly', () {
      expect(
        const PickedFile(
          name: 'a',
          path: '',
          extension: '',
          mimeType: '',
          sizeBytes: 500,
        ).sizeFormatted,
        '500 B',
      );
      expect(
        const PickedFile(
          name: 'a',
          path: '',
          extension: '',
          mimeType: '',
          sizeBytes: 1536,
        ).sizeFormatted,
        '1.5 KB',
      );
      expect(
        const PickedFile(
          name: 'a',
          path: '',
          extension: '',
          mimeType: '',
          sizeBytes: 2500000,
        ).sizeFormatted,
        '2.4 MB',
      );
      expect(
        const PickedFile(
          name: 'a',
          path: '',
          extension: '',
          mimeType: '',
          sizeBytes: 3221225472,
        ).sizeFormatted,
        '3.00 GB',
      );
    });

    test('lazy readAsBytes reads full content when file exists', () async {
      final picked = PickedFile(
        name: 'test_doc.pdf',
        path: sampleFile.path,
        extension: 'pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
      );

      final bytes = await picked.readAsBytes();
      expect(bytes, [1, 2, 3, 4, 5]);
    });

    test(
      'readAsBytes throws FileNotFoundException when file does not exist',
      () async {
        const picked = PickedFile(
          name: 'missing.pdf',
          path: '/non_existent/path/missing.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 0,
        );

        expect(
          () => picked.readAsBytes(),
          throwsA(isA<FileNotFoundException>()),
        );
      },
    );

    test('openRead streams content in chunks without error', () async {
      final picked = PickedFile(
        name: 'test_doc.pdf',
        path: sampleFile.path,
        extension: 'pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
      );

      final chunks = <int>[];
      await for (final chunk in picked.openRead()) {
        chunks.addAll(chunk);
      }
      expect(chunks, [1, 2, 3, 4, 5]);
    });

    test('saveTo copies file to destination creating directories', () async {
      final picked = PickedFile(
        name: 'test_doc.pdf',
        path: sampleFile.path,
        extension: 'pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
      );

      final destPath = '${tempDir.path}/sub/folder/saved.pdf';
      final savedFile = await picked.saveTo(destPath);

      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.readAsBytes(), [1, 2, 3, 4, 5]);
    });

    test(
      'saveTo throws FileNotFoundException when source file is missing',
      () async {
        const picked = PickedFile(
          name: 'missing.pdf',
          path: '/non_existent/missing.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 0,
        );

        expect(
          () => picked.saveTo('${tempDir.path}/dest.pdf'),
          throwsA(isA<FileNotFoundException>()),
        );
      },
    );

    test('equality and hashCode work properly', () {
      final file1 = PickedFile(
        name: 'a.txt',
        path: '/a/path',
        extension: 'txt',
        mimeType: 'text/plain',
        sizeBytes: 10,
      );
      final file2 = PickedFile(
        name: 'a.txt',
        path: '/a/path',
        extension: 'txt',
        mimeType: 'text/plain',
        sizeBytes: 10,
      );
      final file3 = PickedFile(
        name: 'b.txt',
        path: '/b/path',
        extension: 'txt',
        mimeType: 'text/plain',
        sizeBytes: 20,
      );

      expect(file1, equals(file2));
      expect(file1.hashCode, equals(file2.hashCode));
      expect(file1, isNot(equals(file3)));
    });
  });
}
