class ScreenshotItem {
  final String id;
  final String assetId;
  final String? localPath;
  final String extractedText;
  final String category;
  final bool isKept;
  final DateTime dateAdded;
  final bool isProcessed;

  const ScreenshotItem({
    required this.id,
    required this.assetId,
    this.localPath,
    required this.extractedText,
    required this.category,
    required this.isKept,
    required this.dateAdded,
    required this.isProcessed,
  });

  ScreenshotItem copyWith({
    String? id,
    String? assetId,
    String? localPath,
    String? extractedText,
    String? category,
    bool? isKept,
    DateTime? dateAdded,
    bool? isProcessed,
  }) {
    return ScreenshotItem(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      localPath: localPath ?? this.localPath,
      extractedText: extractedText ?? this.extractedText,
      category: category ?? this.category,
      isKept: isKept ?? this.isKept,
      dateAdded: dateAdded ?? this.dateAdded,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asset_id': assetId,
      'local_path': localPath,
      'extracted_text': extractedText,
      'category': category,
      'is_kept': isKept ? 1 : 0,
      'date_added': dateAdded.toIso8601String(),
      'is_processed': isProcessed ? 1 : 0,
    };
  }

  factory ScreenshotItem.fromMap(Map<String, dynamic> map) {
    return ScreenshotItem(
      id: map['id'] as String,
      assetId: map['asset_id'] as String,
      localPath: map['local_path'] as String?,
      extractedText: map['extracted_text'] as String? ?? '',
      category: map['category'] as String? ?? 'unclassified',
      isKept: (map['is_kept'] as int? ?? 0) == 1,
      dateAdded: DateTime.parse(map['date_added'] as String),
      isProcessed: (map['is_processed'] as int? ?? 0) == 1,
    );
  }
}

/// Category constants used throughout the app
class ScreenshotCategory {
  static const receipt = 'receipt';
  static const password = 'password';
  static const code = 'code';
  static const contact = 'contact';
  static const url = 'url';
  static const unclassified = 'unclassified';

  static const all = [receipt, password, code, contact, url, unclassified];

  static String label(String category) {
    switch (category) {
      case receipt:
        return 'Receipt';
      case password:
        return 'Password';
      case code:
        return 'Code';
      case contact:
        return 'Contact';
      case url:
        return 'URL';
      default:
        return 'Other';
    }
  }

  static String emoji(String category) {
    switch (category) {
      case receipt:
        return '🧾';
      case password:
        return '🔐';
      case code:
        return '💻';
      case contact:
        return '📇';
      case url:
        return '🔗';
      default:
        return '📷';
    }
  }
}
