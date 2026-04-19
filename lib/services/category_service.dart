import 'package:sweptie/models/screenshot_item.dart';

class CategoryService {
  CategoryService._();

  // ── QR Code ───────────────────────────────────────────────────────────────
  // Any one strong keyword = QR Code
  static const _qrStrong = [
    'qr code', 'scan qr', 'scan the qr', 'qr:', 'barcode',
    'scan to connect', 'wifi password', 'wi-fi password',
    'wireless password', 'network password',
  ];
  // Two or more of these weak ones also qualify
  static const _qrWeak = [
    'ssid', 'wpa2', 'wpa3', 'wep', 'network key', 'passphrase',
    'scan to', 'scan with',
  ];

  // ── Receipt ───────────────────────────────────────────────────────────────
  // Any one strong keyword = Receipt
  static const _receiptStrong = [
    'official receipt', 'sales invoice', 'payment receipt', 'tax invoice',
    'order receipt', 'e-receipt', 'receipt no', 'invoice no', 'invoice #',
    'receipt #', 'transaction id', 'order confirmation', 'order #',
    'order number',
  ];
  // Two or more weak signals also qualify (prevents TikTok comment false positives)
  static const _receiptWeak = [
    'subtotal', 'grand total', 'amount due', 'total due', 'amount paid',
    'total amount', '₱', 'paid', 'change due', 'cash tendered',
    'payment method', 'card ending', 'qty', 'quantity',
    'vat', 'discount', 'cashier', 'transaction',
  ];

  // ── Code ─────────────────────────────────────────────────────────────────
  // High-precision markers — 2 alone = Code, OR 1 + any moderate = Code
  static const _codeHighPrecision = [
    // Print / output statements
    'console.log', 'print(', 'println(', 'printf(', 'echo ',
    // Package managers / VCS (terminal screenshots)
    'npm run', 'npm install', 'git commit', 'git push', 'git clone', 'git status',
    'pip install', 'flutter run', 'flutter build', 'dart ',
    // Language-specific syntax
    '#include', 'using namespace std',
    'def __', '__init__', 'self.',
    'import {', "from '", "from \"", 'require(',
    'select * from', 'insert into', 'create table', 'drop table',
    'public static void', 'public class',
    '() {', '() =>', ') => {',
    // Comment syntax — extremely common in code editor screenshots
    '// ', '/* ', ' */',
    // HTML tags — web dev screenshots
    '<html', '</div>', '<div ', '<body', '</html>',
    // Code file extensions — appear in IDE tab bars when screenshotting
    '.dart', '.java', '.kt', '.swift',
    '.js', '.ts', '.tsx', '.jsx', '.vue',
    '.py', '.rb', '.php', '.cs', '.cpp', '.c',
    '.go', '.rs',
  ];
  // Moderate markers — need 3+ alone, or 1 high-precision + 1 moderate
  static const _codeModerate = [
    'import ', 'function ', 'class ', 'def ',
    'const ', 'let ', 'var ', 'return ',
    'if (', 'for (', 'while (',
    'async ', 'await ',
    'public ', 'private ', 'void ',
    'int ', 'string ', 'bool ',
    'null', 'true', 'false',
    '=>', '};', ');',
  ];

  // ── Contact ───────────────────────────────────────────────────────────────
  // Regex patterns for Philippine phone number formats
  static final _phoneRegexes = [
    // Mobile: 09XXXXXXXXX (11 digits)
    RegExp(r'\b0[89]\d{9}\b'),
    // With country code: +639XXXXXXXXX or 639XXXXXXXXX
    RegExp(r'\+?63[89]\d{9}\b'),
    // Formatted mobile: 0912 345 6789 or 0912-345-6789
    RegExp(r'\b0\d{3}[\s\-]\d{3}[\s\-]\d{4}\b'),
    // Landline with area code: (043) 123 4567, (02) 8123 4567
    RegExp(r'\(\d{2,4}\)\s*\d{3,4}[\s\-]?\d{3,4}'),
  ];
  static const _contactKeywords = [
    '@gmail.com', '@yahoo.com', '@hotmail.com', '@outlook.com',
    'email:', 'e-mail:', 'phone:', 'mobile:', 'tel:', 'contact:',
    'call us', 'call at', 'reach us',
  ];

  // ── Notes ─────────────────────────────────────────────────────────────────

  // Strong academic/scientific signals — any one = Notes
  static const _notesStrong = [
    // Greek / math symbols that OCR does pick up
    '∑', '∫', '∂', '√', 'π', 'θ', 'λ', 'μ', 'σ', 'ω',
    '≠', '≤', '≥', '≈', '∞', '±', '∴', '∵', '∝',
    // Logic / proof arrows
    '→', '←', '↔', '⇒', '⇔',
    // Chemical formulas
    'h₂o', 'co₂', 'h2o', 'co2', 'nacl', 'h2so4', 'c6h12o6',
    // Formal academic note markers (handwritten or typed)
    'theorem:', 'proof:', 'corollary:', 'lemma:', 'definition:',
    'given:', 'solution:', 'let x', 'let n ', 'let y',
    'chapter ', 'lecture ', 'lesson plan',
    // Common handwritten shorthand OCR picks up
    'def:', 'thm:', 'ex:', 'eg:', 'soln:', 'ans:',
    'q.e.d', 'n.b.', 'i.e.', 'e.g.',
    // Tablet note-taking apps — title bar / UI text OCR picks up in screenshots
    'samsung notes', 'goodnotes', 'notability', 'microsoft onenote',
    'onenote', 'evernote', 'squid', 'nebo', 'myscript', 'bamboo paper',
    'google keep', 'zoho notebook', 'penultimate',
  ];

  // Weak academic signals — need 2+ to qualify normally,
  // OR just 1 if the OCR text is sparse (handwriting proxy — see classify()).
  static const _notesWeak = [
    // Study session words
    'formula', 'equation', 'hypothesis', 'conclusion', 'summary',
    'topic:', 'note:', 'notes:', 'review', 'exam', 'quiz',
    'homework', 'assignment', 'lab report', 'experiment',
    // Subject names
    'biology', 'chemistry', 'physics', 'mathematics', 'algebra',
    'calculus', 'geometry', 'trigonometry', 'statistics',
    'history', 'literature', 'psychology', 'sociology',
    'economics', 'accountancy', 'accounting', 'philosophy',
    'engineering', 'anatomy', 'physiology', 'genetics',
    // Common note structure words
    'definition', 'theory', 'concept', 'example:',
    'problem:', 'answer:', 'step 1', 'step 2', 'step 3',
    'objective', 'overview', 'introduction', 'outline',
    'scientific', 'periodic table', 'element', 'compound',
    'reaction', 'molecule', 'atom', 'cell', 'organism',
    'force', 'velocity', 'acceleration', 'momentum', 'energy',
    'voltage', 'current', 'resistance',
  ];

  // Regex patterns for mathematical expressions — strong handwriting signal
  static final _mathExpressions = [
    // Equations: "x = 5", "y = mx + b", "f(x) =", "2x + 3 ="
    RegExp(r'\b[a-zA-Z]\s*=\s*[\d\-\+]'),
    RegExp(r'f\([a-zA-Z]\)\s*='),
    // Fractions written as "3/4", "a/b" next to other math
    RegExp(r'\b\d+\s*/\s*\d+\b'),
    // Superscripts as "x^2", "r^2", "10^3"
    RegExp(r'[a-zA-Z\d]\^[0-9]+'),
    // Numbered list items: "1.", "2.", "3." (3 or more = likely notes outline)
    RegExp(r'(?:^|\n)\s*[1-9]\.\s', multiLine: true),
  ];

  /// Classifies the extracted [text] into a category string.
  static String classify(String text) {
    if (text.trim().isEmpty) return ScreenshotCategory.unclassified;

    final lower = text.toLowerCase();

    // ── QR Code ──────────────────────────────────────────────────────────
    if (_matchesAny(lower, _qrStrong)) return ScreenshotCategory.qrcode;
    if (_countMatches(lower, _qrWeak) >= 2) return ScreenshotCategory.qrcode;

    // ── Receipt ──────────────────────────────────────────────────────────
    if (_matchesAny(lower, _receiptStrong)) return ScreenshotCategory.receipt;
    if (_countMatches(lower, _receiptWeak) >= 2) return ScreenshotCategory.receipt;

    // ── Code ─────────────────────────────────────────────────────────────
    final highPrecisionCount = _countMatches(lower, _codeHighPrecision);
    final moderateCount = _countMatches(lower, _codeModerate);
    if (highPrecisionCount >= 2) return ScreenshotCategory.code;
    if (highPrecisionCount >= 1 && moderateCount >= 1) return ScreenshotCategory.code;
    if (moderateCount >= 3) return ScreenshotCategory.code;

    // ── Contact ──────────────────────────────────────────────────────────
    if (_matchesPhone(text)) return ScreenshotCategory.contact;
    if (_matchesAny(lower, _contactKeywords)) return ScreenshotCategory.contact;

    // ── Notes ────────────────────────────────────────────────────────────
    if (_matchesAny(lower, _notesStrong)) return ScreenshotCategory.notes;
    if (_matchesMath(text)) return ScreenshotCategory.notes;
    if (_countMatches(lower, _notesWeak) >= 2) return ScreenshotCategory.notes;

    // Handwriting proxy: OCR on handwriting produces sparse, fragmented text.
    // If word count is low (< 40) AND at least one academic keyword hit,
    // it's very likely a photo of handwritten notes rather than a random image.
    final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < 40 && _countMatches(lower, _notesWeak) >= 1) {
      return ScreenshotCategory.notes;
    }

    return ScreenshotCategory.unclassified;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw.toLowerCase())) return true;
    }
    return false;
  }

  static int _countMatches(String text, List<String> keywords) {
    int count = 0;
    for (final kw in keywords) {
      if (text.contains(kw.toLowerCase())) count++;
    }
    return count;
  }

  static bool _matchesPhone(String text) {
    for (final pattern in _phoneRegexes) {
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }

  /// Returns true if the text contains recognisable mathematical expressions.
  /// Checks for equations, fractions, exponents, or 3+ numbered list items.
  static bool _matchesMath(String text) {
    int regexHits = 0;
    for (final pattern in _mathExpressions) {
      if (pattern == _mathExpressions.last) {
        // Numbered list: require 3+ items to avoid false positives
        final matches = pattern.allMatches(text);
        if (matches.length >= 3) return true;
      } else {
        if (pattern.hasMatch(text)) regexHits++;
        if (regexHits >= 2) return true;
      }
    }
    return false;
  }
}
