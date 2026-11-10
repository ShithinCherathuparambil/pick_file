import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pick_file/pick_file.dart';

void main() {
  runApp(const PickFileExampleApp());
}

class PickFileExampleApp extends StatelessWidget {
  const PickFileExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pick File Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<PickedFile> _selectedFiles = [];
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _handleAction(
    String label,
    Future<dynamic> Function() action,
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Launching $label...';
    });

    try {
      final result = await action();
      if (!mounted) return;

      if (result == null) {
        _showSnackbar('Selection cancelled');
      } else if (result is PickedFile) {
        setState(() {
          _selectedFiles.insert(0, result);
        });
        _showSnackbar('Picked: ${result.name}');
      } else if (result is List<PickedFile>) {
        if (result.isEmpty) {
          _showSnackbar('Selection cancelled');
        } else {
          setState(() {
            _selectedFiles.insertAll(0, result);
          });
          _showSnackbar('Picked ${result.length} files');
        }
      }
    } on PickFileException catch (e) {
      if (!mounted) return;
      _showErrorDialog(e);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(PickFileException exception) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(exception.runtimeType.toString()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code: ${exception.code}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(exception.message),
            if (exception.details != null) ...[
              const SizedBox(height: 8),
              Text(
                'Details: ${exception.details}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _testStreamRead(PickedFile file) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StreamingDialog(file: file),
    );
  }

  Future<void> _testSaveTo(PickedFile file) async {
    try {
      final tempDir = Directory.systemTemp;
      final targetPath =
          '${tempDir.path}/saved_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final savedFile = await file.saveTo(targetPath);
      final exists = await savedFile.exists();
      final length = exists ? await savedFile.length() : 0;

      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('File Saved Successfully'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Destination Path:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              SelectableText(
                savedFile.path,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text('Verified Size on Disk: $length bytes'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Save failed: $e', isError: true);
    }
  }

  Future<void> _clearCache() async {
    try {
      await PickFile.clearCache();
      if (!mounted) return;
      _showSnackbar('Temporary cache cleared successfully');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Failed to clear cache: $e', isError: true);
    }
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'webm':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return Icons.folder_zip;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'json':
      case 'xml':
      case 'txt':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'mkv':
        return Colors.blue;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Colors.orange;
      case 'zip':
      case 'tar':
      case '7z':
        return Colors.amber.shade800;
      case 'doc':
      case 'docx':
        return Colors.indigo;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick File Plugin Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Cache',
            onPressed: _isLoading ? null : _clearCache,
          ),
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear List',
              onPressed: () {
                setState(() {
                  _selectedFiles.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildActionGrid(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Files (${_selectedFiles.length})',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedFiles.isEmpty)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No files selected yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap any button above to pick files from SAF or Files app.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._selectedFiles.map(_buildFileCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Picker Actions',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.file_open, size: 18),
                  label: const Text('Pick Single File'),
                  onPressed: () => _handleAction(
                    'Pick Single File',
                    () => PickFile.single(),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.copy, size: 18),
                  label: const Text('Pick Multiple Files'),
                  onPressed: () => _handleAction(
                    'Pick Multiple Files',
                    () => PickFile.multiple(),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Pick PDF Document'),
                  onPressed: () => _handleAction(
                    'Pick PDF',
                    () => PickFile.documents(extensions: ['pdf']),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.description, size: 18),
                  label: const Text('Pick Office / Docs'),
                  onPressed: () => _handleAction(
                    'Pick Documents',
                    () => PickFile.documents(),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.image, size: 18),
                  label: const Text('Pick Images as Files'),
                  onPressed: () =>
                      _handleAction('Pick Images', () => PickFile.images()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.video_library, size: 18),
                  label: const Text('Pick Videos'),
                  onPressed: () =>
                      _handleAction('Pick Videos', () => PickFile.videos()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.audiotrack, size: 18),
                  label: const Text('Pick Audio'),
                  onPressed: () =>
                      _handleAction('Pick Audio', () => PickFile.audio()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.folder_zip, size: 18),
                  label: const Text('Pick Archives (ZIP/7Z)'),
                  onPressed: () =>
                      _handleAction('Pick Archives', () => PickFile.archives()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.filter_alt, size: 18),
                  label: const Text('Custom: pdf, docx, csv'),
                  onPressed: () => _handleAction(
                    'Pick Custom Extensions',
                    () => PickFile.custom(extensions: ['pdf', 'docx', 'csv']),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.sd_storage, size: 18),
                  label: const Text('Limit Size (<= 5 MB)'),
                  onPressed: () => _handleAction(
                    'Pick with 5 MB Limit',
                    () => PickFile.single(
                      options: const FilePickOptions(
                        maxSizeBytes: 5 * 1024 * 1024,
                      ),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.format_list_numbered, size: 18),
                  label: const Text('Limit Count (<= 3 files)'),
                  onPressed: () => _handleAction(
                    'Pick Max 3 Files',
                    () => PickFile.multiple(
                      options: const FilePickOptions(
                        allowMultiple: true,
                        maxFiles: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(PickedFile file) {
    final icon = _getFileIcon(file.extension);
    final iconColor = _getIconColor(file.extension);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.15),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${file.sizeFormatted} • .${file.extension.toUpperCase()} • ${file.mimeType}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedFiles.remove(file);
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              'Local Cache Path:',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            SelectableText(
              file.path,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.stream, size: 16),
                  label: const Text('Stream Read'),
                  onPressed: () => _testStreamRead(file),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.save_alt, size: 16),
                  label: const Text('Save to...'),
                  onPressed: () => _testSaveTo(file),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingDialog extends StatefulWidget {
  const _StreamingDialog({required this.file});

  final PickedFile file;

  @override
  State<_StreamingDialog> createState() => _StreamingDialogState();
}

class _StreamingDialogState extends State<_StreamingDialog> {
  int _chunksRead = 0;
  int _totalBytesStreamed = 0;
  bool _isStreaming = true;
  String? _error;
  final List<int> _firstChunkPreview = [];

  @override
  void initState() {
    super.initState();
    _startStreaming();
  }

  Future<void> _startStreaming() async {
    try {
      final stream = widget.file.openRead();
      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          _chunksRead++;
          _totalBytesStreamed += chunk.length;
          if (_firstChunkPreview.length < 64) {
            _firstChunkPreview.addAll(
              chunk.take(64 - _firstChunkPreview.length),
            );
          }
        });
      }
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.stream, color: Colors.blue),
          SizedBox(width: 8),
          Text('Streaming File Chunks'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File: ${widget.file.name}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Reported File Size: ${widget.file.sizeFormatted}'),
          Text('Chunks Received: $_chunksRead'),
          Text('Bytes Streamed: $_totalBytesStreamed bytes'),
          const SizedBox(height: 12),
          if (_isStreaming)
            const LinearProgressIndicator()
          else if (_error != null)
            Text('Error: $_error', style: const TextStyle(color: Colors.red))
          else
            const Text(
              'Streaming finished without buffering whole file into RAM!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (_firstChunkPreview.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Initial Byte Sample (Hex):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _firstChunkPreview
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' '),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
