import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/screens/detail_screen.dart';
import 'package:sweptie/services/database_service.dart';

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  List<List<ScreenshotItem>> _groups = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final groups = await DatabaseService.instance.getDuplicateCandidates();
    if (mounted) setState(() { _groups = groups; _isLoading = false; });
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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    bool alsoDeleteFromGallery = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Delete $count duplicate${count > 1 ? 's' : ''}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected duplicates will be removed from Sweptie.'),
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

    final allItems = _groups.expand((g) => g).toList();
    final selectedItems =
        allItems.where((e) => _selectedIds.contains(e.id)).toList();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count duplicate${count > 1 ? 's' : ''} removed')),
      );
      _selectedIds.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0D1F33), const Color(0xFF1565C0)]
                  : [const Color(0xFF0D47A1), const Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Duplicates',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _EmptyState(onRefresh: _load)
              : Column(
                  children: [
                    _Header(
                      groupCount: _groups.length,
                      totalCount: _groups.fold(0, (s, g) => s + g.length),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _groups.length,
                        itemBuilder: (context, i) {
                          final group = _groups[i];
                          return _DuplicateGroup(
                            group: group,
                            selectedIds: _selectedIds,
                            onToggle: _toggleSelect,
                            onTap: (item) async {
                              final updated =
                                  await Navigator.push<ScreenshotItem>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => DetailScreen(item: item)),
                              );
                              if (updated != null && mounted) {
                                await _load();
                              }
                            },
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
}

class _Header extends StatelessWidget {
  final int groupCount;
  final int totalCount;
  const _Header({required this.groupCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.purple.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.copy_all_rounded, color: Colors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$groupCount group${groupCount > 1 ? 's' : ''} · $totalCount screenshots with identical text',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.purple),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroup extends StatelessWidget {
  final List<ScreenshotItem> group;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  final void Function(ScreenshotItem) onTap;

  const _DuplicateGroup({
    required this.group,
    required this.selectedIds,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = group.first.extractedText;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            children: [
              if (group.length > 1)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _TileThumb(item: group[1]),
                ),
              Positioned(
                left: 0,
                top: 0,
                child: _TileThumb(item: group.first),
              ),
            ],
          ),
        ),
        title: Text(
          '${group.length} duplicates',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        children: group.map((item) {
          final isSelected = selectedIds.contains(item.id);
          final dateStr =
              DateFormat('MMM d, yyyy').format(item.dateAdded);
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: GestureDetector(
              onTap: () => onToggle(item.id),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.localPath != null
                        ? Image.file(
                            File(item.localPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _thumb(),
                          )
                        : _thumb(),
                  ),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(128),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
                '${ScreenshotCategory.emoji(item.category)} ${ScreenshotCategory.label(item.category)}',
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(dateStr,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(item.id),
            ),
            onTap: () => onTap(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _thumb() => Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image, color: Colors.grey, size: 20),
      );
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
          Icon(Icons.check_circle_outline,
              size: 72, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text('No duplicates found!',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('All your screenshots have unique content.',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500)),
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

class _TileThumb extends StatelessWidget {
  final ScreenshotItem item;
  const _TileThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: item.localPath != null
          ? Image.file(
              File(item.localPath!),
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: 36,
        height: 36,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image, color: Colors.grey, size: 16),
      );
}
