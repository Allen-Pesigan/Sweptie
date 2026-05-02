import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
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
      final isManualFile = _item.assetId.startsWith('/');

      if (isManualFile) {
        final file = File(_item.assetId);
        if (await file.exists()) await file.delete();
      } else {
        try {
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

  // ── QR helpers ──────────────────────────────────────────────────────────────

  String? _detectUrl(String text) {
    final trimmed = text.trim();
    final urlRegex = RegExp(
        r'https?://[^\s]+|www\.[^\s]+',
        caseSensitive: false);
    final match = urlRegex.firstMatch(trimmed);
    if (match == null) return null;
    final url = match.group(0)!;
    return url.startsWith('http') ? url : 'https://$url';
  }

  Map<String, String>? _detectWifi(String text) {
    final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(text);
    final passMatch = RegExp(r'P:([^;]+)').firstMatch(text);
    if (ssidMatch == null) return null;
    return {
      'ssid': ssidMatch.group(1) ?? '',
      'password': passMatch?.group(1) ?? '',
    };
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(_item.dateAdded);

    final isQr = _item.category == 'qrcode';
    final detectedUrl = isQr ? _detectUrl(_item.extractedText) : null;
    final wifiInfo = isQr ? _detectWifi(_item.extractedText) : null;

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
        title: Text(
          '${ScreenshotCategory.emoji(_item.category)} ${ScreenshotCategory.label(_item.category)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
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
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _item.localPath != null
                    ? Image.file(
                        File(_item.localPath!),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),

            const SizedBox(height: 14),

            // Date
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Keep / Delete buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleKeep,
                    icon: Icon(_item.isKept
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
                    label: Text(_item.isKept ? 'Kept' : 'Keep'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _item.isKept
                          ? Colors.amber.shade700
                          : cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── QR Code actions ──────────────────────────────────────────────
            if (isQr && (detectedUrl != null || wifiInfo != null)) ...[
              const SizedBox(height: 20),
              Text('Quick Action',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cs.onSurface)),
              const SizedBox(height: 10),
              if (detectedUrl != null)
                _QrActionCard(
                  icon: Icons.open_in_browser_rounded,
                  color: Colors.blue,
                  label: 'Open URL',
                  subtitle: detectedUrl,
                  onTap: () => _openUrl(detectedUrl),
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: detectedUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied')),
                    );
                  },
                ),
              if (wifiInfo != null)
                _QrActionCard(
                  icon: Icons.wifi_rounded,
                  color: Colors.green,
                  label: 'WiFi: ${wifiInfo['ssid']}',
                  subtitle: wifiInfo['password']!.isEmpty
                      ? 'No password'
                      : 'Password: ${wifiInfo['password']}',
                  onTap: null,
                  onCopy: wifiInfo['password']!.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(
                              ClipboardData(text: wifiInfo['password']!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('WiFi password copied')),
                          );
                        },
                ),
            ],

            const SizedBox(height: 24),

            // Extracted text section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extracted Text',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                if (_item.extractedText.isNotEmpty)
                  TextButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                _item.extractedText.isEmpty
                    ? 'No text was found in this screenshot.'
                    : _item.extractedText,
                style: TextStyle(
                  fontSize: 14,
                  color: _item.extractedText.isEmpty
                      ? cs.onSurfaceVariant
                      : cs.onSurface,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, size: 52, color: Colors.blue.shade300),
      ),
    );
  }
}

// ── QR action card ────────────────────────────────────────────────────────────

class _QrActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;

  const _QrActionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCopy != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy',
                onPressed: onCopy,
              ),
            if (onTap != null)
              FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Open'),
              ),
          ],
        ),
      ),
    );
  }
}

