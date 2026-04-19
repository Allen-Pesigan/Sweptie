import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/services/database_service.dart';

class DetailScreen extends StatefulWidget {
  final ScreenshotItem item;

  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late ScreenshotItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _toggleKeep() async {
    final updated = _item.copyWith(isKept: !_item.isKept);
    await DatabaseService.instance.updateScreenshot(updated);
    if (mounted) setState(() => _item = updated);
  }

  Future<void> _delete() async {
    bool alsoDeleteFromGallery = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Delete screenshot?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will remove the record from Sweptie.'),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: alsoDeleteFromGallery,
                onChanged: (v) =>
                    setDialogState(() => alsoDeleteFromGallery = v ?? false),
                title: const Text(
                  'Also delete from gallery',
                  style: TextStyle(fontSize: 14),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    await DatabaseService.instance.deleteScreenshot(_item.id);

    if (alsoDeleteFromGallery) {
      // Manually-added files use the file path as assetId (starts with /).
      // Gallery-synced items use the photo_manager numeric/UUID asset ID.
      final isManualFile = _item.assetId.startsWith('/');

      if (isManualFile) {
        final file = File(_item.assetId);
        if (await file.exists()) await file.delete();
      } else {
        try {
          // On Android 10+ this shows a system confirmation dialog.
          // Returns the list of IDs that were actually deleted.
          final deleted =
              await PhotoManager.editor.deleteWithIds([_item.assetId]);
          if (mounted && deleted.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Gallery deletion was cancelled or denied by the system.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not delete from gallery.'),
              ),
            );
          }
        }
      }
    }

    if (mounted) Navigator.pop(context, _item.copyWith(isProcessed: false));
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _item.extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(_item.dateAdded);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${ScreenshotCategory.emoji(_item.category)} ${ScreenshotCategory.label(_item.category)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove from Sweptie',
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screenshot image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _item.localPath != null
                  ? Image.file(
                      File(_item.localPath!),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),

            const SizedBox(height: 16),

            // Date
            Text(dateStr,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),

            const SizedBox(height: 16),

            // Keep / Delete buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleKeep,
                    icon: Icon(
                        _item.isKept ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(_item.isKept ? 'Kept' : 'Keep'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _item.isKept
                          ? Colors.amber.shade700
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Extracted text section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Extracted Text',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_item.extractedText.isNotEmpty)
                  TextButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _item.extractedText.isEmpty
                    ? 'No text was found in this screenshot.'
                    : _item.extractedText,
                style: TextStyle(
                  fontSize: 14,
                  color: _item.extractedText.isEmpty
                      ? Colors.grey
                      : Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
      ),
    );
  }
}
