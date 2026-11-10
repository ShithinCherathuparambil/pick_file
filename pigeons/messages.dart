import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/example/pick_file/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.pick_file'),
    swiftOut: 'ios/pick_file/Sources/pick_file/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
class PickedFileResult {
  PickedFileResult({
    required this.path,
    required this.name,
    required this.fileExtension,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final String fileExtension;
  final String mimeType;
  final int sizeBytes;
}

class FilePickOptionsDto {
  FilePickOptionsDto({
    required this.allowMultiple,
    this.maxFiles,
    this.maxSizeBytes,
    this.allowedExtensions,
    this.allowedMimeTypes,
    this.filterType,
  });

  final bool allowMultiple;
  final int? maxFiles;
  final int? maxSizeBytes;
  final List<String>? allowedExtensions;
  final List<String>? allowedMimeTypes;
  final String? filterType;
}

@HostApi()
abstract class PickFileHostApi {
  @async
  List<PickedFileResult> pickFiles(FilePickOptionsDto options);

  @async
  void clearCache();
}
