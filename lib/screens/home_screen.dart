import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sweptie/main.dart' show themeModeNotifier, userModelNotifier;
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/screens/detail_screen.dart';
import 'package:sweptie/services/auth_service.dart';
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
    if (state == AppLifecycleState.resumed) {
      _checkPermissionOnly();
    }
  }

  Future<void> _checkPermissionOnly() async {
    final status = await GalleryService.instance.requestPermission();
    if (!mounted) return;
    setState(() => _permissionStatus = status);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sweptie',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            Text(
              _isSyncing ? _syncStatus : '${_items.length} screenshots',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              themeModeNotifier.value =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          ValueListenableBuilder(
            valueListenable: userModelNotifier,
            builder: (context, user, _) {
              final initial = (user?.displayName.isNotEmpty == true)
                  ? user!.displayName[0].toUpperCase()
                  : '?';
              final isPremium = user?.isPremium ?? false;
              return PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (isPremium)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.star_rounded,
                                size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text(user?.email ?? '',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? Colors.amber.shade100
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPremium ? '★ Premium' : 'Free plan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPremium
                                  ? Colors.amber.shade800
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'signout',
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'signout') {
                    await AuthService.instance.signOut();
                  }
                },
              );
            },
          ),
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.no_photography_outlined, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Photo access denied. Sweptie cannot scan your screenshots automatically.',
              style: TextStyle(fontSize: 13, color: cs.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(foregroundColor: cs.onErrorContainer),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.tertiaryContainer,
      padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6, right: 4),
      child: Row(
        children: [
          Icon(Icons.photo_library_outlined, color: cs.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Limited access — only selected photos visible. Grant full access to scan all screenshots.',
              style: TextStyle(fontSize: 13, color: cs.onTertiaryContainer),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(foregroundColor: cs.onTertiaryContainer),
            child: const Text('Allow All'),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: cs.onTertiaryContainer),
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
    final cs = Theme.of(context).colorScheme;
    final categories = ['all', ...ScreenshotCategory.all];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
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
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(cat),
            selectedColor: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
            showCheckmark: false,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: Icon(
                permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.photo_library_outlined,
                size: 56,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSyncing
                  ? 'Scanning your screenshots…'
                  : permissionDenied
                      ? 'No gallery access'
                      : 'No screenshots yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              permissionDenied
                  ? 'You can still add photos manually using the button below.'
                  : 'Pull down to refresh, or add images manually.',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (!isSyncing) ...[
              const SizedBox(height: 28),
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
