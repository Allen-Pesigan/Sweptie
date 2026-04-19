import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sweptie/models/screenshot_item.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'sweptie.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE screenshots (
            id TEXT PRIMARY KEY,
            asset_id TEXT UNIQUE,
            local_path TEXT,
            extracted_text TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT 'unclassified',
            is_kept INTEGER NOT NULL DEFAULT 0,
            date_added TEXT NOT NULL,
            is_processed INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_category ON screenshots(category)',
        );
        await db.execute(
          'CREATE INDEX idx_is_kept ON screenshots(is_kept)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Rename old category values to match new constants
          await db.execute(
            "UPDATE screenshots SET category = 'qrcode' WHERE category = 'password'",
          );
          await db.execute(
            "UPDATE screenshots SET category = 'notes' WHERE category = 'url'",
          );
        }
      },
    );
  }

  Database get _database {
    if (_db == null) throw StateError('DatabaseService not initialized');
    return _db!;
  }

  Future<void> insertScreenshot(ScreenshotItem item) async {
    await _database.insert(
      'screenshots',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateScreenshot(ScreenshotItem item) async {
    await _database.update(
      'screenshots',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<bool> hasAsset(String assetId) async {
    final result = await _database.query(
      'screenshots',
      columns: ['id'],
      where: 'asset_id = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<ScreenshotItem>> getAllScreenshots() async {
    final rows = await _database.query(
      'screenshots',
      orderBy: 'date_added DESC',
    );
    return rows.map(ScreenshotItem.fromMap).toList();
  }

  Future<List<ScreenshotItem>> searchScreenshots(String query) async {
    if (query.trim().isEmpty) return getAllScreenshots();
    final term = '%${query.trim()}%';
    final rows = await _database.query(
      'screenshots',
      where: 'extracted_text LIKE ? OR category LIKE ?',
      whereArgs: [term, term],
      orderBy: 'date_added DESC',
    );
    return rows.map(ScreenshotItem.fromMap).toList();
  }

  Future<List<ScreenshotItem>> getSuggestedForDeletion() async {
    // Suggest screenshots that are: not kept, processed, and either
    // unclassified OR older than 7 days
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final rows = await _database.query(
      'screenshots',
      where: 'is_kept = 0 AND is_processed = 1 AND (category = ? OR date_added < ?)',
      whereArgs: ['unclassified', cutoff.toIso8601String()],
      orderBy: 'date_added ASC',
    );
    return rows.map(ScreenshotItem.fromMap).toList();
  }

  Future<void> deleteScreenshot(String id) async {
    await _database.delete('screenshots', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final rows = await _database.rawQuery(
      'SELECT category, COUNT(*) as count FROM screenshots GROUP BY category',
    );
    return {for (final row in rows) row['category'] as String: row['count'] as int};
  }
}
