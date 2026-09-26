import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../shared/widgets/controls.dart';

class ImageUploadScreen extends ConsumerStatefulWidget {
  const ImageUploadScreen({
    super.key,
    required this.productId,
    required this.returnPath,
  });

  final int productId;
  final String returnPath;

  @override
  ConsumerState<ImageUploadScreen> createState() => _ImageUploadState();
}

class _UploadItem {
  _UploadItem({
    required this.file,
    required this.name,
    required this.size,
    required this.sortOrder,
  });

  final File file;
  final String name;
  final int size;
  final int sortOrder;
  String status = 'pending'; // pending | uploading | done | failed
  String? error;
}

class _ImageUploadState extends ConsumerState<ImageUploadScreen> {
  final _picker = ImagePicker();
  final List<_UploadItem> _items = [];
  final List<String> _selectionErrors = [];
  bool _busy = false;
  bool _picking = false;
  int _nextSortOrder = 0;

  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const _maxBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _recoverLostData();
  }

  Future<void> _recoverLostData() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      final files =
          response.files ?? [if (response.file != null) response.file!];
      if (files.isEmpty) {
        _recordErrors([
          'The interrupted image selection could not be recovered.',
        ]);
      } else {
        await _addPickedFiles(files);
      }
    } catch (_) {
      _recordErrors([
        'The interrupted image selection could not be recovered.',
      ]);
    }
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    try {
      await _addPickedFiles(await _picker.pickMultiImage());
    } catch (e) {
      _recordErrors(['Could not open the image picker: $e']);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addPickedFiles(List<XFile> picked) async {
    if (picked.isEmpty) return;
    final additions = <_UploadItem>[];
    final rejected = <String>[];
    final knownPaths = _items.map((item) => item.file.path).toSet();

    for (final selected in picked) {
      final name = selected.name.isEmpty
          ? selected.path.split('/').last
          : selected.name;
      final extension = name.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(extension)) {
        rejected.add('$name: use a JPG, PNG, or WebP image.');
        continue;
      }
      if (knownPaths.contains(selected.path)) {
        rejected.add('$name: this image is already selected.');
        continue;
      }
      try {
        final file = File(selected.path);
        final size = await file.length();
        if (size > _maxBytes) {
          rejected.add('$name: images must be 5 MB or smaller.');
          continue;
        }
        additions.add(
          _UploadItem(
            file: file,
            name: name,
            size: size,
            sortOrder: _nextSortOrder + additions.length,
          ),
        );
        knownPaths.add(selected.path);
      } catch (_) {
        rejected.add('$name: the selected file is no longer available.');
      }
    }

    if (!mounted) return;
    setState(() {
      _items.addAll(additions);
      _nextSortOrder += additions.length;
      _selectionErrors.addAll(rejected);
    });
  }

  void _recordErrors(List<String> messages) {
    if (mounted) setState(() => _selectionErrors.addAll(messages));
  }

  Future<void> _uploadOne(
    _UploadItem item, {
    bool ignoreGlobalBusy = false,
  }) async {
    if ((!ignoreGlobalBusy && _busy) ||
        item.status == 'uploading' ||
        item.status == 'done') {
      return;
    }
    setState(() {
      item.status = 'uploading';
      item.error = null;
    });
    try {
      await ref
          .read(repositoryProvider)
          .uploadImage(item.file, widget.productId, item.sortOrder);
      if (!mounted) return;
      setState(() => item.status = 'done');
      ref.invalidate(productProvider(widget.productId));
      ref.invalidate(resellerProductsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        item.status = 'failed';
        item.error = '$e';
      });
    }
  }

  Future<void> _uploadAll() async {
    final pending = _items
        .where((item) => item.status == 'pending' || item.status == 'failed')
        .toList();
    if (pending.isEmpty || _busy) return;
    setState(() => _busy = true);
    for (final item in pending) {
      if (!mounted) return;
      await _uploadOne(item, ignoreGlobalBusy: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _retry(_UploadItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _uploadOne(item, ignoreGlobalBusy: true);
    if (mounted) setState(() => _busy = false);
  }

  void _remove(_UploadItem item) {
    if (_busy || item.status == 'uploading' || item.status == 'done') return;
    setState(() => _items.remove(item));
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((item) => item.status == 'done').length;
    final anyPending = _items.any(
      (item) => item.status == 'pending' || item.status == 'failed',
    );
    return Scaffold(
      appBar: MarketplaceAppBar(
        title: const Text('Upload product images'),
        backFallback: widget.returnPath,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => context.go(widget.returnPath),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add product photos from your gallery. JPG, PNG, and WebP images up to 5 MB are supported.',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _picking || _busy ? null : _pick,
                  icon: _picking
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(_picking ? 'Opening gallery…' : 'Add images'),
                ),
                if (_items.isNotEmpty)
                  Text('$done / ${_items.length} uploaded'),
                if (_selectionErrors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final error in _selectionErrors) Text(error),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(_selectionErrors.clear),
                            child: const Text('Dismiss'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No images selected yet.'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.file(item.file, fit: BoxFit.cover),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          item.status == 'failed'
                              ? item.error ?? 'Upload failed'
                              : '${_label(item.status)} • ${_formatBytes(item.size)}',
                          style: item.status == 'failed'
                              ? TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                )
                              : null,
                        ),
                        trailing: item.status == 'failed'
                            ? TextButton(
                                onPressed: _busy ? null : () => _retry(item),
                                child: const Text('Retry'),
                              )
                            : item.status == 'uploading'
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : item.status == 'done'
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove image',
                                onPressed: _busy ? null : () => _remove(item),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: 'Upload selected',
                  loading: _busy,
                  onPressed: _items.isEmpty || !anyPending || _busy
                      ? null
                      : _uploadAll,
                  icon: Icons.upload,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : () => context.go(widget.returnPath),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(String status) {
    switch (status) {
      case 'uploading':
        return 'Uploading…';
      case 'done':
        return 'Uploaded';
      case 'failed':
        return 'Upload failed';
      default:
        return 'Ready to upload';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
