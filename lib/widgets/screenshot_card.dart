import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sweptie/models/screenshot_item.dart';

class ScreenshotCard extends StatelessWidget {
  final ScreenshotItem item;
  final VoidCallback onTap;

  const ScreenshotCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            // Gradient overlay at the bottom for the category chip
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: _buildCategoryChip(context)),
                    if (item.isKept)
                      const Icon(Icons.bookmark, color: Colors.amber, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (item.localPath != null) {
      final file = File(item.localPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    final label =
        '${ScreenshotCategory.emoji(item.category)} ${ScreenshotCategory.label(item.category)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _categoryColor(item.category).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case ScreenshotCategory.receipt:
        return Colors.green.shade700;
      case ScreenshotCategory.password:
        return Colors.red.shade700;
      case ScreenshotCategory.code:
        return Colors.indigo;
      case ScreenshotCategory.contact:
        return Colors.teal;
      case ScreenshotCategory.url:
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
