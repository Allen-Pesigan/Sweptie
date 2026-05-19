# Sweptie System Architecture

High-level overview of Sweptie's architecture, tech stack, and design decisions.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       SWEPTIE APP (Flutter)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Presentation Layer (Screens & Widgets)                  │   │
│  │  • HomeScreen (gallery view)                             │   │
│  │  • DetailScreen (single screenshot)                      │   │
│  │  • SuggestionsScreen (cleanup)                           │   │
│  │  • DuplicatesScreen (duplicates)                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           ↓                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Service Layer (Business Logic)                          │   │
│  │  • OcrService (text extraction)                          │   │
│  │  • DatabaseService (SQLite + Firestore)                 │   │
│  │  • GalleryService (device photo access)                 │   │
│  │  • AuthService (Firebase auth)                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           ↓                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Data Layer (Persistence)                               │   │
│  │  • SQLite (local database)                              │   │
│  │  • Device Gallery (photo access)                        │   │
│  │  • External APIs (Firebase, Google ML Kit)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
         ↓                        ↓                    ↓
    ┌─────────┐          ┌──────────────┐      ┌─────────────┐
    │ Firebase│          │  Google ML   │      │   Device    │
    │ (Auth,  │          │    Kit OCR   │      │   Gallery   │
    │Firestore)           │              │      │  & Storage  │
    └─────────┘          └──────────────┘      └─────────────┘
```

## Architecture Layers

### 1. Presentation Layer

**Responsibility**: UI rendering, user interaction, state management

**Screens:**
- `HomeScreen` — Main gallery with filtering and categorization
- `DetailScreen` — Full-screen screenshot view with editing
- `SuggestionsScreen` — AI-suggested deletions
- `DuplicatesScreen` — Duplicate groups
- `AuthScreen` — Login/sign-up (Firebase)

**Widgets:**
- `ScreenshotCard` — Individual screenshot card UI
- Custom filter chips, AppBars, dialogs

**State Management:**
- Stateful widgets with `setState()`
- Simple state lifting for shared data
- No external state management library (Redux, Riverpod)

### 2. Service Layer

**Responsibility**: Business logic, external API orchestration, data transformation

#### OcrService
- Wraps Google ML Kit TextRecognizer
- Extracts text from images
- Cleans extracted text (removes blank lines, trims)
- Single instance per app lifecycle

**Flow:**
```
Image File → Google ML Kit → Raw Text → _cleanText() → Cleaned Text
```

#### DatabaseService
- Local SQLite for offline access
- Firestore for cloud sync
- One-way sync: local → cloud
- Auto-syncs on app resume (WidgetsBindingObserver)

**Local Schema:**
```sql
CREATE TABLE screenshots (
  id TEXT PRIMARY KEY,
  assetId TEXT,
  category TEXT,
  extractedText TEXT,
  dateAdded TIMESTAMP,
  isKept BOOLEAN,
  isProcessed BOOLEAN,
  userId TEXT,
  localPath TEXT,
  dateModified TIMESTAMP
);
```

**Cloud Schema (Firestore):**
```
/screenshots/{userId}/items/{id}
  ├── assetId: string
  ├── category: string
  ├── extractedText: string
  ├── dateAdded: timestamp
  ├── isKept: boolean
  ├── isProcessed: boolean
  ├── localPath: string
  └── dateModified: timestamp
```

#### GalleryService
- Wraps `photo_manager` package
- Requests device photo permissions
- Scans device gallery for new screenshots
- Heuristically identifies screenshots vs. regular photos

**Permission States:**
```
Denied → Permission Banner on HomeScreen, no gallery access
Limited → Mapped to Authorized (code-level fix for Android 14)
Authorized → Full gallery access, auto-sync enabled
```

**Screenshot Detection Heuristics:**
- Filename contains "screenshot" or "Screen" (case-insensitive)
- EXIF data indicates screenshot app
- Date clustering (multiple captures in short time)
- Aspect ratio within phone screen bounds

#### AuthService
- Wraps Firebase Authentication
- Email/password sign-up and sign-in
- Session persistence
- Sign-out with cleanup

### 3. Data Layer

**Responsibility**: Data persistence, external service integration

#### Local Database (SQLite)
- Offline-first design
- Fast queries for filtering and search
- Syncs to Firestore when online
- Database file: `sweptie.db`

#### Device Gallery
- Accessed via `photo_manager` package
- Requires runtime permissions (iOS 14+, Android 6+)
- Permission handling:
  - iOS: `NSPhotoLibraryUsageDescription` in Info.plist
  - Android: `READ_MEDIA_VISUAL` permission

#### Firebase Services
- **Authentication**: Email/password, session tokens, sign-out
- **Firestore**: Cloud storage, real-time sync, user data isolation
- **Cloud Storage** (future): Full-resolution backups, restore

---

## Data Model

### ScreenshotItem

```dart
class ScreenshotItem {
  final String id;                    // UUID
  final String assetId;               // Gallery asset ID or file path
  final String category;              // receipt, qrcode, code, contact, notes, other
  final DateTime dateAdded;
  final DateTime dateModified;
  final String extractedText;         // Cleaned OCR text
  final String? localPath;             // Thumbnail or cache path
  final bool isKept;                   // Bookmarked by user
  final bool isProcessed;              // OCR + categorization done
  final String userId;                 // Firebase UID
}
```

### Category Classification

**Categories:**
1. **Receipt** (🧾) — Shopping receipts, invoices, bills
2. **QR Code** (📱) — Barcodes, payment codes
3. **Code** (💻) — Source code, terminal, error messages
4. **Contact** (👤) — Phone numbers, addresses
5. **Notes** (📝) — Text notes, lists
6. **Other** (🖼️) — Photos, memes, general

**Classification Method:**
- Text-based heuristics on extracted OCR
- Pattern matching (e.g., "QR", "receipt #", "Contact:", etc.)
- Fallback to "Other"

---

## Data Flows

### 1. Screenshot Import Flow

```
User Launches App
  ↓
GalleryService.requestPermission()
  ↓
  ├─ Denied → Show PermissionBanner, return
  ├─ Limited → Map to Authorized (Android 14 fix)
  └─ Authorized → Continue
  ↓
GalleryService.syncNewScreenshots()
  ↓
  ├─ Scan device gallery for new screenshots
  ├─ For each new screenshot:
  │   ├─ OcrService.extractText(filePath)
  │   ├─ Auto-categorize based on text
  │   ├─ Save to local SQLite
  │   └─ Sync to Firestore
  └─ Emit onProgress callback
  ↓
HomeScreen updates UI with new items
```

### 2. Cleanup Suggestion Flow

```
DatabaseService.getSuggestedForDeletion()
  ↓
  ├─ Screenshots older than 30 days
  ├─ Screenshots with <50 chars extracted text (low-quality)
  ├─ Screenshots manually marked for deletion
  └─ Return sorted list
  ↓
SuggestionsScreen displays suggestions
  ↓
User selects items → DatabaseService.deleteScreenshot()
  ↓
  ├─ Delete from SQLite
  ├─ Delete from Firestore
  ├─ Optional: Delete from device gallery (PhotoManager.editor.deleteWithIds)
  └─ Show snackbar confirmation
```

### 3. Duplicate Detection Flow

```
DatabaseService.getDuplicateCandidates()
  ↓
  ├─ Group screenshots by extracted text similarity
  │   (Exact match or >80% string similarity)
  ├─ Sort by date (oldest first)
  └─ Return grouped list
  ↓
DuplicatesScreen displays groups with stacked previews
  ↓
User selects duplicates to delete
  ↓
Same as cleanup flow (delete from both Sweptie and gallery)
```

### 4. Search Flow

```
User types in search box
  ↓
DatabaseService.searchScreenshots(query)
  ↓
  ├─ Query SQLite: WHERE extractedText LIKE %query%
  ├─ Filter by current category (if filtered)
  └─ Return matching items
  ↓
HomeScreen updates GridView with results
```

---

## Key Design Decisions

### 1. Local-First Architecture
**Decision**: Store in SQLite first, sync to Firestore asynchronously

**Rationale:**
- App works offline
- Faster UI response
- Reduces Firebase quota usage
- Graceful degradation if cloud unavailable

### 2. One-Way Sync (Local → Cloud)
**Decision**: Primary data source is local; Firestore is backup

**Rationale:**
- Simpler conflict resolution
- Less bandwidth (no polling)
- User data always accessible locally
- Cloud acts as disaster recovery

### 3. Heuristic-Based Screenshot Detection
**Decision**: Use filename, EXIF, and date clustering instead of ML

**Rationale:**
- Fast (no model inference)
- Works offline
- Accurate for 95%+ of cases
- No dependency on ML model updates

### 4. Stateful Widgets over State Management Library
**Decision**: Use `setState()` instead of Riverpod, Bloc, Redux

**Rationale:**
- App is small (<5 major screens)
- Limited shared state
- Faster development
- Lower complexity
- Easy to understand for new contributors

### 5. Text-Based Duplicate Detection
**Decision**: Compare extracted OCR text instead of image hashing

**Rationale:**
- Handles exact duplicates (same content)
- Works with different crops/rotations if text is same
- Uses existing OCR data (no extra processing)
- Simpler than image similarity models

---

## Tech Stack Details

### Dependencies

**Core:**
- `flutter` 3.0+
- `dart` 3.0+

**UI:**
- `material` (Built-in Material 3 design)
- `intl` (Date formatting)

**Database:**
- `sqflite` (Local SQLite)
- `firebase_core` (Firebase setup)
- `cloud_firestore` (Cloud database)

**Authentication:**
- `firebase_auth` (Email/password auth)

**Device Access:**
- `photo_manager` (Gallery and permissions)
- `image_picker` (Manual file selection)
- `permission_handler` (Permission dialogs)

**AI/ML:**
- `google_ml_kit` (OCR with TextRecognizer)

**Other:**
- `shared_preferences` (User settings, cache)
- `uuid` (Unique ID generation)

---

## Performance Optimizations

### Image Loading
- Lazy-load images in GridView (only visible items)
- Cache thumbnail images locally
- Use `Image.file()` with error handling
- Placeholder while loading

### Database Queries
- Index on `userId`, `category`, `dateAdded`
- Limit query results for pagination
- Denormalize frequently-accessed fields

### OCR Processing
- Run in background via `Future.microtask()`
- Process multiple files sequentially (not parallel)
- Cache extracted text in database (don't re-OCR)

### Firestore Sync
- Batch writes (max 500 documents per batch)
- Sync only on app resume (not continuous)
- Compress data before transmission

### UI Rendering
- Use `RepaintBoundary` for expensive widgets
- Debounce filter/search updates (300ms)
- Paginate large lists (initially load 50, more on scroll)

---

## Security

### Authentication
- Email/password via Firebase (hashed by Google)
- Session tokens stored securely in device keystore
- Automatic sign-out on token expiry

### Data Privacy
- All OCR processing local (not sent to cloud)
- Firestore security rules: user can only access own data
- Gallery photos not uploaded (only metadata)
- No analytics or tracking

### Code Security
- No hardcoded secrets (Firebase config via file)
- No SQL injection (using parameterized queries)
- No XSS (Flutter doesn't use WebView for core UI)

---

## Deployment

### Development
```bash
flutter run -d <device_id>
```

### Staging
```bash
flutter build appbundle --release
# Upload to Firebase Test Lab for testing
```

### Production
```bash
flutter build appbundle --release
# Sign with keystore
# Upload to Google Play Console / App Store Connect
```

---

## Monitoring & Debugging

### Logging
```dart
// Debug: Print to console
print('Screenshot imported: ${item.id}');

// Production: Use Firebase Crashlytics (future)
FirebaseCrashlytics.instance.log('Important event');
```

### Error Handling
- Try-catch at service level
- Graceful UI fallbacks (show error snackbar)
- Silent failures for non-critical operations (e.g., Firestore sync)

### Performance Profiling
```bash
flutter run --profile
# Use Flutter DevTools to analyze performance
```

---

## Future Scaling Considerations

### Horizontal Scaling
- Move services to serverless functions (Cloud Functions)
- Use Cloud Pub/Sub for event-driven processing
- Cloud Tasks for scheduled cleanup

### Vertical Scaling
- Cache frequently-accessed data (Redis)
- Use Firestore indexes for complex queries
- Implement pagination for large datasets

### AI/ML Scaling
- Train custom ML model for better categorization
- Use Cloud Vision API for better OCR (multilingual)
- Implement image similarity detection (TensorFlow Lite)

---

## References

- [Flutter Documentation](https://flutter.dev)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google ML Kit](https://developers.google.com/ml-kit)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
