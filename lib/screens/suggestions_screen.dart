import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/screens/detail_screen.dart';
import 'package:sweptie/screens/duplicates_screen.dart';
import 'package:sweptie/services/database_service.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  List<ScreenshotItem> _suggestions = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await DatabaseService.instance.getSuggestedForDeletion();
    if (mounted) setState(() { _suggestions = items; _isLoading = false; });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _suggestions.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_suggestions.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    bool alsoDeleteFromGallery = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Delete $count screenshot${count > 1 ? 's' : ''}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected screenshots will be removed from Sweptie.'),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: alsoDeleteFromGallery,
                onChanged: (v) =>
                    setDialogState(() => alsoDeleteFromGallery = v ?? false),
                title: const Text('Also delete from gallery',
                    style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final selectedItems =
        _suggestions.where((e) => _selectedIds.contains(e.id)).toList();

    for (final id in _selectedIds) {
      await DatabaseService.instance.deleteScreenshot(id);
    }

    if (alsoDeleteFromGallery) {
      final galleryIds = selectedItems
          .where((e) => !e.assetId.startsWith('/'))
          .map((e) => e.assetId)
          .toList();
      if (galleryIds.isNotEmpty) {
        await PhotoManager.editor.deleteWithIds(galleryIds);
      }
      for (final item in selectedItems.where((e) => e.assetId.startsWith('/'))) {
        final file = File(item.assetId);
        if (await file.exists()) await file.delete();
      }
    }

    if (mounted) {
      setState(() {
        _suggestions.removeWhere((e) => _selectedIds.contains(e.id));
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count screenshot${count > 1 ? 's' : ''} removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.difference_rounded, size: 18),
            label: const Text('Duplicates'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DuplicatesScreen()),
            ),
          ),
          if (_suggestions.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIds.length == _suggestions.length
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suggestions.isEmpty
              ? _EmptyState(onRefresh: _load)
              : Column(
                  children: [
                    _SuggestionHeader(count: _suggestions.length),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          final isSelected = _selectedIds.contains(item.id);
                          return _SuggestionTile(
                            item: item,
                            isSelected: isSelected,
                            onTap: () => _openDetail(item),
                            onToggle: () => _toggleSelect(item.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelected,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete_sweep),
              label: Text('Delete ${_selectedIds.length}'),
            )
          : null,
    );
  }

  Future<void> _openDetail(ScreenshotItem item) async {
    final updated = await Navigator.push<ScreenshotItem>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _suggestions.indexWhere((e) => e.id == updated.id);
        if (idx != -1) _suggestions[idx] = updated;
        // Remove if kept or deleted
        if (updated.isKept || !updated.isProcessed) {
          _suggestions.removeWhere((e) => e.id == updated.id);
          _selectedIds.remove(updated.id);
        }
      });
    }
  }
}

class _SuggestionHeader extends StatelessWidget {
  final int count;
  const _SuggestionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.auto_delete_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count screenshot${count > 1 ? 's' : ''} suggested for cleanup',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final ScreenshotItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _SuggestionTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(item.dateAdded);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: onToggle,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.localPath != null
                  ? Image.file(
                      File(item.localPath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(128),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        '${ScreenshotCategory.emoji(item.category)} ${ScreenshotCategory.label(item.category)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          if (item.extractedText.isNotEmpty)
            Text(
              item.extractedText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            )
          else
            Text(
              'No text found',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade400),
            ),
        ],
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (_) => onToggle(),
      ),
      onTap: onTap,
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text(
            "You're all clean!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No screenshots flagged for cleanup right now.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
