import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pick_file/pick_file.dart';
import 'package:pick_file/src/platform/messages.g.dart';

class MockPickFileHostApi extends PickFileHostApi {
  List<PickedFileResult> Function(FilePickOptionsDto options)? onPickFiles;
  Future<void> Function()? onClearCache;

  FilePickOptionsDto? lastPickOptions;
  bool clearCacheCalled = false;

  @override
  Future<List<PickedFileResult>> pickFiles(FilePickOptionsDto options) async {
    lastPickOptions = options;
    if (onPickFiles != null) {
      return onPickFiles!(options);
    }
    return [];
  }

  @override
  Future<void> clearCache() async {
    clearCacheCalled = true;
    if (onClearCache != null) {
      await onClearCache!();
    }
  }
}

void main() {
  late MockPickFileHostApi mockApi;

  setUp(() {
    mockApi = MockPickFileHostApi();
    PickFile.setMockHostApi(mockApi);
  });

  tearDown(() {
    PickFile.setMockHostApi(null);
  });

  group('PickFile.single', () {
    test('returns PickedFile when a file is picked', () async {
      mockApi.onPickFiles = (options) => [
        PickedFileResult(
          name: 'contract.pdf',
          path: '/cache/contract.pdf',
          fileExtension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
        ),
      ];

      final file = await PickFile.single();

      expect(file, isNotNull);
      expect(file!.name, 'contract.pdf');
      expect(file.path, '/cache/contract.pdf');
      expect(file.extension, 'pdf');
      expect(file.mimeType, 'application/pdf');
      expect(file.sizeBytes, 1024);
      expect(mockApi.lastPickOptions?.allowMultiple, isFalse);
    });

    test('returns null when user cancels single file picking', () async {
      mockApi.onPickFiles = (options) => [];

      final file = await PickFile.single();
      expect(file, isNull);
    });
  });

  group('PickFile.multiple', () {
    test('returns list of PickedFile when files are picked', () async {
      mockApi.onPickFiles = (options) => [
        PickedFileResult(
          name: 'sheet.xlsx',
          path: '/cache/sheet.xlsx',
          fileExtension: 'xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          sizeBytes: 2048,
        ),
        PickedFileResult(
          name: 'notes.txt',
          path: '/cache/notes.txt',
          fileExtension: 'txt',
          mimeType: 'text/plain',
          sizeBytes: 512,
        ),
      ];

      final files = await PickFile.multiple();

      expect(files.length, 2);
      expect(files[0].name, 'sheet.xlsx');
      expect(files[1].name, 'notes.txt');
      expect(mockApi.lastPickOptions?.allowMultiple, isTrue);
    });

    test(
      'returns empty list when user cancels multiple file picking',
      () async {
        mockApi.onPickFiles = (options) => [];

        final files = await PickFile.multiple();
        expect(files, isEmpty);
      },
    );
  });

  group('PickFile convenience methods', () {
    test('PickFile.documents passes document filter type', () async {
      mockApi.onPickFiles = (options) => [
        PickedFileResult(
          name: 'doc.pdf',
          path: '/cache/doc.pdf',
          fileExtension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 100,
        ),
      ];

      final file = await PickFile.documents();
      expect(file, isNotNull);
      expect(mockApi.lastPickOptions?.filterType, 'documents');
    });

    test('PickFile.documentsMultiple returns multiple documents', () async {
      mockApi.onPickFiles = (options) => [
        PickedFileResult(
          name: 'doc1.pdf',
          path: '/cache/doc1.pdf',
          fileExtension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 100,
        ),
        PickedFileResult(
          name: 'doc2.docx',
          path: '/cache/doc2.docx',
          fileExtension: 'docx',
          mimeType: 'application/msword',
          sizeBytes: 200,
        ),
      ];

      final files = await PickFile.documentsMultiple();
      expect(files.length, 2);
      expect(mockApi.lastPickOptions?.allowMultiple, isTrue);
      expect(mockApi.lastPickOptions?.filterType, 'documents');
    });

    test('PickFile.images passes images filter type', () async {
      mockApi.onPickFiles = (options) => [];
      await PickFile.images();
      expect(mockApi.lastPickOptions?.filterType, 'images');
    });

    test('PickFile.videos passes videos filter type', () async {
      mockApi.onPickFiles = (options) => [];
      await PickFile.videos();
      expect(mockApi.lastPickOptions?.filterType, 'videos');
    });

    test('PickFile.audio passes audio filter type', () async {
      mockApi.onPickFiles = (options) => [];
      await PickFile.audio();
      expect(mockApi.lastPickOptions?.filterType, 'audio');
    });

    test('PickFile.archives passes archives filter type', () async {
      mockApi.onPickFiles = (options) => [];
      await PickFile.archives();
      expect(mockApi.lastPickOptions?.filterType, 'archives');
    });

    test('PickFile.custom passes custom extensions', () async {
      mockApi.onPickFiles = (options) => [];
      await PickFile.custom(extensions: ['pdf', '.csv']);
      expect(mockApi.lastPickOptions?.filterType, 'custom');
      expect(mockApi.lastPickOptions?.allowedExtensions, ['pdf', 'csv']);
    });
  });

  group('Dart layer secondary validation', () {
    test(
      'throws MaximumFileCountExceededException when count exceeds limit',
      () async {
        mockApi.onPickFiles = (options) => [
          PickedFileResult(
            name: '1.pdf',
            path: '/1.pdf',
            fileExtension: 'pdf',
            mimeType: 'application/pdf',
            sizeBytes: 10,
          ),
          PickedFileResult(
            name: '2.pdf',
            path: '/2.pdf',
            fileExtension: 'pdf',
            mimeType: 'application/pdf',
            sizeBytes: 10,
          ),
        ];

        expect(
          () => PickFile.multiple(
            options: const FilePickOptions(allowMultiple: true, maxFiles: 1),
          ),
          throwsA(isA<MaximumFileCountExceededException>()),
        );
      },
    );

    test(
      'throws MaximumSizeExceededException when file size exceeds maxSizeBytes',
      () async {
        mockApi.onPickFiles = (options) => [
          PickedFileResult(
            name: 'huge.pdf',
            path: '/huge.pdf',
            fileExtension: 'pdf',
            mimeType: 'application/pdf',
            sizeBytes: 2048,
          ),
        ];

        expect(
          () => PickFile.single(
            options: const FilePickOptions(maxSizeBytes: 1024),
          ),
          throwsA(isA<MaximumSizeExceededException>()),
        );
      },
    );

    test(
      'throws UnsupportedFileTypeException when extension is disallowed',
      () async {
        mockApi.onPickFiles = (options) => [
          PickedFileResult(
            name: 'virus.exe',
            path: '/virus.exe',
            fileExtension: 'exe',
            mimeType: 'application/octet-stream',
            sizeBytes: 1024,
          ),
        ];

        expect(
          () => PickFile.custom(extensions: ['pdf']),
          throwsA(isA<UnsupportedFileTypeException>()),
        );
      },
    );
  });

  group('Platform error handling', () {
    test('maps PlatformException picker_busy to PickerBusyException', () async {
      mockApi.onPickFiles = (options) {
        throw PlatformException(
          code: 'picker_busy',
          message: 'Another picker is busy',
        );
      };

      expect(() => PickFile.single(), throwsA(isA<PickerBusyException>()));
    });

    test('maps PlatformException provider_unavailable to ProviderUnavailableException', () async {
      mockApi.onPickFiles = (options) {
        throw PlatformException(
          code: 'provider_unavailable',
          message: 'Cloud drive unavailable',
        );
      };

      expect(
        () => PickFile.single(),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });

    test(
      'maps PlatformException file_access_denied to FileAccessDeniedException',
      () async {
        mockApi.onPickFiles = (options) {
          throw PlatformException(
            code: 'file_access_denied',
            message: 'Security error',
          );
        };

        expect(
          () => PickFile.single(),
          throwsA(isA<FileAccessDeniedException>()),
        );
      },
    );

    test('maps PlatformException insufficient_storage to InsufficientStorageException', () async {
      mockApi.onPickFiles = (options) {
        throw PlatformException(
          code: 'insufficient_storage',
          message: 'Out of space',
        );
      };

      expect(
        () => PickFile.single(),
        throwsA(isA<InsufficientStorageException>()),
      );
    });
  });

  group('PickFile.clearCache', () {
    test('invokes host API clearCache', () async {
      expect(mockApi.clearCacheCalled, isFalse);
      await PickFile.clearCache();
      expect(mockApi.clearCacheCalled, isTrue);
    });

    test('rethrows typed exception on PlatformException', () async {
      mockApi.onClearCache = () {
        throw PlatformException(
          code: 'platform_unavailable',
          message: 'Host failed',
        );
      };

      expect(
        () => PickFile.clearCache(),
        throwsA(isA<PlatformUnavailableException>()),
      );
    });
  });
}
