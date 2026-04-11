import 'package:sweptie/models/screenshot_item.dart';

class CategoryService {
  CategoryService._();

  static const _receiptKeywords = [
    'total', 'subtotal', 'tax', 'invoice', 'receipt', 'order', 'payment',
    'amount due', 'grand total', 'price', 'qty', 'quantity', 'item',
    r'$', '€', '£', '₱', 'paid', 'change', 'cash', 'card', 'transaction',
  ];

  static const _passwordKeywords = [
    'password', 'passwd', 'pwd', 'wifi', 'wi-fi', 'ssid', 'network key',
    'passphrase', 'login', 'username', 'credentials', 'secret key',
    'access key', 'api key', 'token', 'otp', 'pin',
  ];

  static const _codeKeywords = [
    'import ', 'function ', 'class ', 'def ', 'const ', 'var ', 'let ',
    'return ', 'public ', 'private ', 'void ', 'int ', 'string ', 'bool',
    '=> ', '() {', 'async ', 'await ', '#include', 'print(', 'console.log',
    'SELECT ', 'FROM ', 'WHERE ', 'INSERT ', 'UPDATE ', 'npm ', 'git ',
  ];

  static const _contactKeywords = [
    '@gmail', '@yahoo', '@hotmail', '@outlook', '.com', 'phone:', 'mobile:',
    'tel:', 'email:', 'contact:', 'call us', '+1', '+44', '+63',
  ];

  static const _urlKeywords = [
    'http://', 'https://', 'www.', '.com/', '.org/', '.net/', '.io/',
    '.ph/', '.gov/', 'ftp://',
  ];

  /// Classifies the extracted [text] into a category string.
  static String classify(String text) {
    if (text.trim().isEmpty) return ScreenshotCategory.unclassified;

    final lower = text.toLowerCase();

    if (_matchesAny(lower, _urlKeywords)) return ScreenshotCategory.url;
    if (_matchesAny(lower, _passwordKeywords)) return ScreenshotCategory.password;
    if (_matchesAny(lower, _receiptKeywords)) return ScreenshotCategory.receipt;
    if (_matchesAny(lower, _codeKeywords)) return ScreenshotCategory.code;
    if (_matchesAny(lower, _contactKeywords)) return ScreenshotCategory.contact;

    return ScreenshotCategory.unclassified;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw.toLowerCase())) return true;
    }
    return false;
  }
}
