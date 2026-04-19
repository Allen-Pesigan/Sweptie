import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/screens/detail_screen.dart';
import 'package:sweptie/services/database_service.dart';
import 'package:sweptie/services/gallery_service.dart';
import 'package:sweptie/widgets/screenshot_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ScreenshotItem> _items = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _syncStatus = '';
  PhotoPermissionStatus? _permissionStatus;
  String _selectedCategory = 'all';
  // Lets the user manually hide the limited-access banner if the OS permission
  // API keeps returning "limited" even after they've granted full access.
  bool _limitedBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromDb();
    _syncFromGallery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from the system Settings page re-check permission only —
    // no need to re-scan the whole gallery just to update the banner.
    if (state == AppLifecycleState.resumed) {
      _checkPermissionOnly();
    }
  }

  /// Re-checks the current permission state and updates the banner without
  /// triggering a full gallery sync.
  Future<void> _checkPermissionOnly() async {
    final status = await GalleryService.instance.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      // If the OS now correctly reports full access, reset the dismissed flag
      // so the banner won't reappear if they later revoke and re-grant.
      if (status == PhotoPermissionStatus.authorized) {
        _limitedBannerDismissed = false;
      }
    });
    // If they just upgraded from limited → authorized, sync to pick up newly
    // accessible photos.
    if (status == PhotoPermissionStatus.authorized && _items.isEmpty) {
      _syncFromGallery();
    }
  }

  Future<void> _loadFromDb() async {
    setState(() => _isLoading = true);
    final items = await DatabaseService.instance.getAllScreenshots();
    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _syncFromGallery() async {
    final status = await GalleryService.instance.requestPermission();
    if (mounted) setState(() => _permissionStatus = status);

    if (status == PhotoPermissionStatus.denied) return;

    if (mounted) setState(() { _isSyncing = true; _syncStatus = 'Scanning gallery…'; });

    await GalleryService.instance.syncNewScreenshots(
      onProgress: (item) {
        if (mounted) {
          setState(() {
            _syncStatus = 'Tagged: ${ScreenshotCategory.label(item.category)}';
            _items = [item, ..._items.where((e) => e.id != item.id)];
          });
        }
      },
    );

    final items = await DatabaseService.instance.getAllScreenshots();
    if (mounted) {
      setState(() {
        _items = items;
        _isSyncing = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _pickManualImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    setState(() { _isSyncing = true; _syncStatus = 'Processing ${picked.length} image(s)…'; });

    for (final xfile in picked) {
      final item = await GalleryService.instance.processManualFile(xfile.path);
      if (mounted) {
        setState(() {
          _syncStatus = 'Tagged: ${ScreenshotCategory.label(item.category)}';
          _items = [item, ..._items.where((e) => e.id != item.id)];
        });
      }
    }

    final items = await DatabaseService.instance.getAllScreenshots();
    if (mounted) setState(() { _items = items; _isSyncing = false; _syncStatus = ''; });
  }

  List<ScreenshotItem> get _filtered {
    if (_selectedCategory == 'all') return _items;
    return _items.where((e) => e.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sweptie', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          if (_isSyncing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_syncStatus, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          if (!_isSyncing)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Sync gallery',
              onPressed: () { _loadFromDb(); _syncFromGallery(); },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_permissionStatus == PhotoPermissionStatus.denied)
            _PermissionBanner(onOpenSettings: GalleryService.instance.openSettings),
          if (_permissionStatus == PhotoPermissionStatus.limited && !_limitedBannerDismissed)
            _LimitedAccessBanner(
              onOpenSettings: GalleryService.instance.openSettings,
              onDismiss: () => setState(() => _limitedBannerDismissed = true),
            ),
          _CategoryFilterBar(
            selected: _selectedCategory,
            onSelected: (cat) => setState(() => _selectedCategory = cat),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _EmptyState(
                        isSyncing: _isSyncing,
                        permissionDenied:
                            _permissionStatus == PhotoPermissionStatus.denied,
                        onAddManually: _pickManualImages,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadFromDb();
                          await _syncFromGallery();
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final item = _filtered[index];
                            return ScreenshotCard(
                              item: item,
                              onTap: () => _openDetail(item),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSyncing ? null : _pickManualImages,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add Photos'),
        tooltip: 'Pick images manually from gallery',
      ),
    );
  }

  Future<void> _openDetail(ScreenshotItem item) async {
    final updated = await Navigator.push<ScreenshotItem>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
    if (updated != null && mounted) _loadFromDb();
  }
}

// ── Banners ──────────────────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _PermissionBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.red),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Photo access denied. Sweptie cannot scan your screenshots automatically.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _LimitedAccessBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;
  const _LimitedAccessBanner({required this.onOpenSettings, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6, right: 4),
      child: Row(
        children: [
          const Icon(Icons.photo_library_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Limited access — only selected photos visible. Grant full access to scan all screenshots.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Allow All'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.orange),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;

  const _CategoryFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = ['all', ...ScreenshotCategory.all];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return FilterChip(
            label: Text(
              cat == 'all'
                  ? 'All'
                  : '${ScreenshotCategory.emoji(cat)} ${ScreenshotCategory.label(cat)}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : null,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(cat),
            selectedColor: Theme.of(context).colorScheme.primary,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSyncing;
  final bool permissionDenied;
  final VoidCallback onAddManually;

  const _EmptyState({
    required this.isSyncing,
    required this.permissionDenied,
    required this.onAddManually,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              permissionDenied
                  ? Icons.no_photography_outlined
                  : Icons.photo_library_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isSyncing
                  ? 'Scanning your screenshots…'
                  : permissionDenied
                      ? 'No gallery access'
                      : 'No screenshots yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              permissionDenied
                  ? 'You can still add photos manually using the button below.'
                  : 'Pull down to refresh, or add images manually.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
            if (!isSyncing) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddManually,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Photos'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
