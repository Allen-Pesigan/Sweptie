import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/services/category_service.dart';
import 'package:sweptie/services/database_service.dart';
import 'package:sweptie/services/ocr_service.dart';

enum PhotoPermissionStatus { authorized, limited, denied }

class GalleryService {
  GalleryService._();
  static final GalleryService instance = GalleryService._();

  /// Requests photo library access.
  /// Returns [authorized] for full access, [limited] for partial (Android 14+
  /// "select photos" or iOS 14+ limited library), [denied] otherwise.
  Future<PhotoPermissionStatus> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps == PermissionState.authorized || ps == PermissionState.limited) {
      return PhotoPermissionStatus.authorized;
    }
    return PhotoPermissionStatus.denied;
  }

  /// Opens the device's app-permission settings page.
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Loads all assets from the Screenshots album (Android) or all images (iOS).
  Future<List<AssetEntity>> loadScreenshotAssets() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(needTitle: true),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    // Prefer the Screenshots album on Android
    AssetPathEntity? target;
    for (final album in albums) {
      if (album.name.toLowerCase() == 'screenshots') {
        target = album;
        break;
      }
    }
    // Fall back to the all-photos album
    target ??= albums.isNotEmpty ? albums.first : null;
    if (target == null) return [];

    final count = await target.assetCountAsync;
    if (count == 0) return [];
    return target.getAssetListRange(start: 0, end: count);
  }

  /// Scans new gallery assets, runs OCR on each, and saves to DB.
  /// Calls [onProgress] after each processed item.
  Future<void> syncNewScreenshots({
    required void Function(ScreenshotItem item) onProgress,
  }) async {
    final assets = await loadScreenshotAssets();
    final db = DatabaseService.instance;

    for (final asset in assets) {
      if (await db.hasAsset(asset.id)) continue;

      final File? file = await asset.file;
      if (file == null) continue;

      final item = await _buildItem(
        id: asset.id,
        assetId: asset.id,
        filePath: file.path,
        dateAdded: asset.createDateTime,
      );

      await db.insertScreenshot(item);
      onProgress(item);
    }
  }

  /// Processes a single manually-picked file (from image_picker).
  /// Uses the file path as both id and assetId since it has no gallery asset ID.
  Future<ScreenshotItem> processManualFile(String filePath) async {
    final db = DatabaseService.instance;
    // Use path as unique key so re-adding the same file is a no-op
    if (await db.hasAsset(filePath)) {
      // Return the already-stored record
      final all = await db.getAllScreenshots();
      return all.firstWhere(
        (e) => e.assetId == filePath,
        orElse: () => _placeholderItem(filePath),
      );
    }

    final item = await _buildItem(
      id: filePath,
      assetId: filePath,
      filePath: filePath,
      dateAdded: DateTime.now(),
    );

    await db.insertScreenshot(item);
    return item;
  }

  Future<ScreenshotItem> _buildItem({
    required String id,
    required String assetId,
    required String filePath,
    required DateTime dateAdded,
  }) async {
    final extractedText = await OcrService.instance.extractText(filePath);
    final category = CategoryService.classify(extractedText);
    return ScreenshotItem(
      id: id,
      assetId: assetId,
      localPath: filePath,
      extractedText: extractedText,
      category: category,
      isKept: false,
      dateAdded: dateAdded,
      isProcessed: true,
    );
  }

  ScreenshotItem _placeholderItem(String filePath) => ScreenshotItem(
        id: filePath,
        assetId: filePath,
        localPath: filePath,
        extractedText: '',
        category: ScreenshotCategory.unclassified,
        isKept: false,
        dateAdded: DateTime.now(),
        isProcessed: false,
      );
}
