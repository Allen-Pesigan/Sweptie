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
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            // 3-stop gradient for better text legibility over any image
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x66000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: _buildCategoryChip()),
                    if (item.isKept)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
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
      return Image.file(
        File(item.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, color: Colors.blue.shade300, size: 40),
      ),
    );
  }

  Widget _buildCategoryChip() {
    final color = _categoryColor(item.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(100),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${ScreenshotCategory.emoji(item.category)} ${ScreenshotCategory.label(item.category)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case ScreenshotCategory.receipt:
        return const Color(0xFF2E7D32);
      case ScreenshotCategory.qrcode:
        return const Color(0xFF6A1B9A);
      case ScreenshotCategory.code:
        return const Color(0xFF1565C0);
      case ScreenshotCategory.contact:
        return const Color(0xFF00695C);
      case ScreenshotCategory.notes:
        return const Color(0xFF0277BD);
      default:
        return const Color(0xFF546E7A);
    }
  }
}
