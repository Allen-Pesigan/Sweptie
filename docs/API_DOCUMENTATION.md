# Sweptie API Documentation

Complete reference for all services, models, and APIs in Sweptie.

## Table of Contents

1. [Models](#models)
2. [Services](#services)
3. [Screens](#screens)
4. [Widgets](#widgets)

---

## Models

### ScreenshotItem

Represents a single screenshot in the database.

```dart
class ScreenshotItem {
  final String id;                    // Unique identifier (UUID)
  final String assetId;               // Gallery asset ID or local file path
  final String category;              // One of: receipt, qrcode, code, contact, notes, other
  final DateTime dateAdded;            // When screenshot was added to Sweptie
  final DateTime dateModified;         // Last modification time
  final String extractedText;          // OCR-extracted text from screenshot
  final String? localPath;             // Local file path to thumbnail
  final bool isKept;                   // User marked as important (bookmarked)
  final bool isProcessed;              // OCR & categorization completed
  final String userId;                 // Firebase user ID
}
```

#### ScreenshotCategory (Constants)
```dart
class ScreenshotCategory {
  static const String receipt = 'receipt';
  static const String qrcode = 'qrcode';
  static const String code = 'code';
  static const String contact = 'contact';
  static const String notes = 'notes';
  static const String other = 'other';
  
  static const List<String> all = [receipt, qrcode, code, contact, notes, other];
  
  // Get emoji for category
  static String emoji(String category) { ... }
  
  // Get display label for category
  static String label(String category) { ... }
}
```

### PhotoPermissionStatus

```dart
enum PhotoPermissionStatus {
  authorized,    // User granted full access
  limited,       // User granted limited access (iOS 14+)
  denied,        // User denied access
}
```

---

## Services

### OcrService

Singleton service for text extraction from images using Google ML Kit.

#### Methods

**`extractText(String filePath) -> Future<String>`**

Extracts text from an image file and cleans it.

```dart
final text = await OcrService.instance.extractText('/path/to/image.jpg');
// Returns: Cleaned text with blank lines removed, per-line trimmed
```

**Parameters:**
- `filePath` (String): Absolute path to image file (JPEG, PNG, WebP)

**Returns:**
- `Future<String>`: Extracted text, newline-separated, empty lines removed

**Error Handling:**
- Returns empty string if extraction fails
- Catches and silently handles ML Kit errors

---

### DatabaseService

Singleton service for SQLite (local) and Firestore (cloud) database operations.

#### Methods

**`getAllScreenshots() -> Future<List<ScreenshotItem>>`**

Retrieves all screenshots for the current user from local database.

```dart
final items = await DatabaseService.instance.getAllScreenshots();
```

**`getSuggestedForDeletion() -> Future<List<ScreenshotItem>>`**

Gets screenshots suggested for deletion (low-quality, old, or flagged).

```dart
final suggestions = await DatabaseService.instance.getSuggestedForDeletion();
// Returns items older than 30 days, low text quality, or manually marked
```

**`getDuplicateCandidates() -> Future<List<List<ScreenshotItem>>>`**

Groups screenshots with identical or very similar extracted text.

```dart
final groups = await DatabaseService.instance.getDuplicateCandidates();
// Returns: List of groups, each group contains duplicate items
```

**`saveScreenshot(ScreenshotItem item) -> Future<void>`**

Saves or updates a screenshot in both local SQLite and Firestore.

```dart
await DatabaseService.instance.saveScreenshot(item);
```

**Parameters:**
- `item` (ScreenshotItem): Screenshot to save

**`deleteScreenshot(String id) -> Future<void>`**

Deletes a screenshot from both local and cloud storage.

```dart
await DatabaseService.instance.deleteScreenshot(screenshotId);
```

**Parameters:**
- `id` (String): Screenshot ID to delete

**`searchScreenshots(String query) -> Future<List<ScreenshotItem>>`**

Searches screenshots by extracted text content.

```dart
final results = await DatabaseService.instance.searchScreenshots('receipt');
// Returns all screenshots with "receipt" in extracted text
```

**Parameters:**
- `query` (String): Search term

---

### GalleryService

Singleton service for device photo library access and syncing.

#### Methods

**`requestPermission() -> Future<PhotoPermissionStatus>`**

Requests photo library access from user.

```dart
final status = await GalleryService.instance.requestPermission();
if (status == PhotoPermissionStatus.authorized) {
  // User granted permission
}
```

**Returns:**
- `PhotoPermissionStatus.authorized` — Full access granted
- `PhotoPermissionStatus.limited` — Limited access (iOS 14+, mapped to authorized)
- `PhotoPermissionStatus.denied` — User denied or dismissed

**`syncNewScreenshots({required Function(ScreenshotItem) onProgress}) -> Future<void>`**

Scans device gallery for new screenshots and processes them.

```dart
await GalleryService.instance.syncNewScreenshots(
  onProgress: (item) {
    print('Processed: ${item.category}');
    setState(() => _items.add(item));
  },
);
```

**Parameters:**
- `onProgress` (callback): Invoked for each screenshot processed, passes `ScreenshotItem`

**Behavior:**
- Identifies screenshots using device heuristics (filename patterns, EXIF data)
- Runs OCR via OcrService
- Auto-categorizes using ML model
- Saves to local SQLite and syncs to Firestore
- Skips already-processed screenshots

**`processManualFile(String filePath) -> Future<ScreenshotItem>`**

Processes a single manually-selected file (from image picker).

```dart
final item = await GalleryService.instance.processManualFile(xfile.path);
```

**Parameters:**
- `filePath` (String): Path to image file

**Returns:**
- `ScreenshotItem`: Processed screenshot with OCR and category

**`openSettings() -> Future<void>`**

Opens device settings to photo permissions screen.

```dart
await GalleryService.instance.openSettings();
```

---

### AuthService

Singleton service for Firebase Authentication.

#### Methods

**`signUp(String email, String password) -> Future<void>`**

Creates a new user account.

```dart
await AuthService.instance.signUp('user@example.com', 'password123');
```

**Throws:**
- `FirebaseAuthException` on invalid email, weak password, or existing account

**`signIn(String email, String password) -> Future<void>`**

Signs in existing user.

```dart
await AuthService.instance.signIn('user@example.com', 'password123');
```

**Throws:**
- `FirebaseAuthException` on invalid credentials

**`signOut() -> Future<void>`**

Signs out current user.

```dart
await AuthService.instance.signOut();
```

**`get currentUser -> User?`**

Returns current authenticated user or null if signed out.

```dart
final user = AuthService.instance.currentUser;
if (user != null) {
  print('Signed in as: ${user.email}');
}
```

---

## Screens

### HomeScreen

Main gallery view with filtering, categorization, and sync.

**State Variables:**
- `_items` — All screenshots
- `_selectedCategory` — Currently filtered category ('all', 'receipt', etc.)
- `_isSyncing` — Whether gallery sync is in progress
- `_permissionStatus` — Current gallery permission status

**Key Methods:**
- `_syncFromGallery()` — Initiates gallery sync
- `_loadFromDb()` — Loads screenshots from database
- `_filtered` — Returns screenshots matching selected category

**UI Components:**
- Gradient AppBar with theme toggle and user menu
- Category filter bar with counts
- GridView of screenshot cards
- Floating action button for manual file addition
- Permission banner (if access denied)

---

### DetailScreen

Full-screen view of a single screenshot with editing capabilities.

**Passed Arguments:**
- `item` (ScreenshotItem): Screenshot to display

**Key Features:**
- Full-size image view
- Extracted text display
- Category selection/editing
- Bookmark toggle
- Delete option
- Mark as kept/discard

---

### SuggestionsScreen

Shows AI-suggested screenshots for deletion.

**Key Methods:**
- `_load()` — Loads suggested deletions from database
- `_toggleSelect()` — Select/deselect for bulk deletion
- `_selectAll()` — Quick select all or deselect all
- `_deleteSelected()` — Bulk delete with confirmation

**Navigation:**
- "Duplicates" button → Navigate to DuplicatesScreen

---

### DuplicatesScreen

Shows duplicate screenshot groups with deletion options.

**UI Components:**
- Grouped view with stacked thumbnail previews
- Expandable duplicate groups
- Selection checkboxes
- Bulk delete action

---

## Widgets

### ScreenshotCard

Displays a single screenshot in grid view.

```dart
ScreenshotCard(
  item: screenshotItem,
  onTap: () => Navigator.push(...),
)
```

**Props:**
- `item` (ScreenshotItem): Screenshot to display
- `onTap` (VoidCallback): Callback when card tapped

**Features:**
- Image with gradient overlay
- Date label
- Category chip with emoji
- Bookmark badge (if isKept)
- Error placeholder for missing images

---

## Data Flow

### Import Flow
```
User Permission → GalleryService.syncNewScreenshots()
  ↓
Photo.Manager scans gallery
  ↓
OcrService.extractText() for each new screenshot
  ↓
DatabaseService.saveScreenshot() (SQLite + Firestore)
  ↓
HomeScreen updates UI with new items
```

### Cleanup Flow
```
User views SuggestionsScreen
  ↓
DatabaseService.getSuggestedForDeletion()
  ↓
User selects items and confirms deletion
  ↓
DatabaseService.deleteScreenshot() for each
  ↓
Optional: PhotoManager.editor.deleteWithIds() (remove from gallery)
  ↓
UI updates, snackbar shown
```

### Duplicate Detection Flow
```
User views DuplicatesScreen
  ↓
DatabaseService.getDuplicateCandidates()
  ↓
Groups items by extracted text similarity
  ↓
User selects duplicates to delete
  ↓
Same deletion flow as cleanup
```

---

## Error Handling

### Permission Denied
- Banner shown on HomeScreen
- User directed to Settings
- Gallery sync disabled

### OCR Failure
- Returns empty string
- Screenshot saved with empty extractedText
- Still appears in gallery, just unsearchable

### Firebase Sync Failure
- Screenshot saved to local SQLite
- Syncs to Firestore when connection restored
- User sees "Syncing..." status

### Database Errors
- Caught at service level
- Logged to console (debug mode)
- App continues with graceful degradation

---

## Configuration

### Feature Flags / Constants

**OcrService:**
- Uses `TextRecognitionScript.latin` for English

**DatabaseService:**
- Firestore collection: `screenshots`
- SQLite database: `sweptie.db`
- Auto-sync interval: On app resume (didChangeAppLifecycleState)

**GalleryService:**
- Screenshot detection: Heuristic-based (filename, EXIF, date clustering)
- Auto-categorization: ML model in `processManualFile()`

---

## Testing

### Unit Tests

```dart
// Test OcrService
test('OcrService extracts and cleans text', () async {
  final text = await OcrService.instance.extractText(testImagePath);
  expect(text, isNotEmpty);
  expect(text, isNotContaining('\n\n')); // No blank lines
});

// Test DatabaseService
test('DatabaseService saves and retrieves screenshot', () async {
  final item = ScreenshotItem(...);
  await DatabaseService.instance.saveScreenshot(item);
  final retrieved = await DatabaseService.instance.getAllScreenshots();
  expect(retrieved, contains(item));
});
```

### Integration Tests

```dart
testWidgets('User can import, view, and delete screenshot', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
  // ... simulate file picker ...
  await tester.pump();
  expect(find.byType(ScreenshotCard), findsWidgets);
});
```

---

## Performance Considerations

- **Image Loading**: Uses `Image.file()` with error handling; large images cached
- **Database Queries**: Indexed by userId, category, dateAdded
- **OCR Processing**: Runs in background; can process multiple files sequentially
- **Firestore Sync**: One-way sync (local → cloud); batched writes

---

## Security

- **Authentication**: Firebase Email/Password
- **Data**: Firestore security rules restrict to authenticated user's own data
- **OCR**: Local processing, no OCR data sent to cloud
- **Gallery**: Scanned from device only, not uploaded raw

---

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) for version history and updates.
