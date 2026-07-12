# Sweptie

**AI-powered screenshot organizer** — Automatically categorize, deduplicate, and organize your screenshot gallery with intelligent cleanup and smart search.

## Overview

Sweptie solves the screenshot clutter problem by:
- **Automatically categorizing** screenshots (receipts, QR codes, documents, contacts, notes) using Google ML Kit OCR
- **Detecting duplicates** and suggesting deletion candidates to save device storage
- **Providing smart retrieval** with organized folders and searchable content
- **Respecting privacy** with local-first processing and Firebase cloud sync

## Features

### Smart AI Detection
Uses Google ML Kit text recognition to automatically categorize screenshots into predefined categories (Receipt, QR Code, Code, Contact, Notes, Other).

### Intelligent Cleanup
- Identifies duplicate screenshots by comparing extracted text
- Suggests unnecessary screenshots for deletion
- Recovers device storage without manual effort

### Easy Retrieval
- Organized folder view by category
- Smart search across extracted text content
- Bookmarking important screenshots
- Quick access to categorized collections

### Multi-Platform Support
- iOS and Android (Flutter)
- Cloud sync via Firebase
- Local SQLite database for offline access

## Architecture

### Tech Stack
- **Frontend**: Flutter 3 / Dart / Material 3
- **Backend**: Firebase (Authentication, Firestore)
- **Database**: SQLite (local) + Firebase (cloud sync)
- **AI/ML**: Google ML Kit (OCR), custom classification models
- **Storage**: Device storage + Cloud backup

### Project Structure
```
lib/
├── main.dart                 # App entry point, theme setup
├── models/
│   └── screenshot_item.dart # Screenshot data model
├── screens/
│   ├── home_screen.dart     # Main gallery view with filtering
│   ├── detail_screen.dart   # Screenshot detail & editing
│   ├── suggestions_screen.dart # Cleanup suggestions
│   ├── duplicates_screen.dart  # Duplicate detection view
│   └── auth_screen.dart     # Firebase authentication
├── services/
│   ├── ocr_service.dart     # Google ML Kit OCR wrapper
│   ├── database_service.dart # SQLite & Firestore sync
│   ├── gallery_service.dart # Photo permission & sync
│   └── auth_service.dart    # Firebase auth
└── widgets/
    └── screenshot_card.dart # Screenshot card UI component
```

## Getting Started

### Prerequisites
- Flutter 3.0+
- Android SDK or Xcode (for iOS)
- Firebase project (for auth & cloud sync)
- Google ML Kit dependencies

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd sweptie
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add your Firebase config files:
     - `android/app/google-services.json`
     - `ios/Runner/GoogleService-Info.plist`
   - Enable Firestore and Authentication in Firebase Console

4. **Run the app**
   ```bash
   flutter run
   ```

## How to Use

### User Flow

1. **Sign In**
   - Create account or sign in with email
   - Grant gallery and photo access permissions

2. **Import Screenshots**
   - App automatically syncs from device gallery
   - Or manually add photos via "Add Photos" button

3. **View Organized Gallery**
   - Screenshots appear categorized automatically
   - Filter by category using the filter bar
   - Bookmarks saved important screenshots

4. **Cleanup & Duplicates**
   - **Suggestions screen**: Review AI-suggested deletions
   - **Duplicates screen**: Find and delete duplicate screenshots
   - Optionally delete from both Sweptie and device gallery

5. **Search & Retrieve**
   - Use search feature to find screenshots by text content
   - Access via organized category folders
   - Quick bookmarking for frequently needed items

## Configuration & Setup

### Android Manifest (Permissions)
```xml
<!-- Photo library access -->
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL" />

<!-- Storage for offline access -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Camera for manual photo capture -->
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS Info.plist
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Access your photos to organize and manage screenshots</string>

<key>NSCameraUsageDescription</key>
<string>Capture photos to add to your screenshot collection</string>
```

### Firebase Setup
1. Create Firebase project at https://console.firebase.google.com
2. Enable:
   - Authentication (Email/Password)
   - Firestore Database
   - Cloud Storage (for backup)
3. Download config files and place in `android/app/` and `ios/Runner/`

## API / Service Documentation

### OcrService
Extracts and cleans text from screenshots using Google ML Kit.

```dart
// Extract text from image file
final text = await OcrService.instance.extractText(filePath);
// Returns: Cleaned, newline-separated text with empty lines removed
```

### DatabaseService
Manages local SQLite database and Firestore sync.

```dart
// Get all screenshots
final items = await DatabaseService.instance.getAllScreenshots();

// Get suggested deletions (low-quality, duplicates, old)
final suggestions = await DatabaseService.instance.getSuggestedForDeletion();

// Get duplicate candidates (same extracted text)
final groups = await DatabaseService.instance.getDuplicateCandidates();

// Save or update screenshot
await DatabaseService.instance.saveScreenshot(item);

// Delete screenshot
await DatabaseService.instance.deleteScreenshot(id);
```

### GalleryService
Handles photo permissions and syncing from device gallery.

```dart
// Request photo library permission
final status = await GalleryService.instance.requestPermission();

// Sync new screenshots from gallery
await GalleryService.instance.syncNewScreenshots(
  onProgress: (item) => print('Tagged: ${item.category}'),
);

// Process manually selected files
final item = await GalleryService.instance.processManualFile(filePath);
```

### AuthService
Firebase authentication wrapper.

```dart
// Sign up
await AuthService.instance.signUp(email, password);

// Sign in
await AuthService.instance.signIn(email, password);

// Sign out
await AuthService.instance.signOut();

// Get current user
final user = AuthService.instance.currentUser;
```

## Screenshot Categories

Screenshots are automatically categorized into:
- **Receipt** 🧾 — Shopping receipts, invoices, bills
- **QR Code** 📱 — QR codes, barcodes
- **Code** 💻 — Source code, terminal output, error messages
- **Contact** 👤 — Phone numbers, addresses, contact info
- **Notes** 📝 — Text notes, lists, reminders
- **Other** 🖼️ — Photos, memes, general images

## Business Model

### Revenue Streams
- **Freemium**: Core features free; premium unlocks unlimited cleanup (₹99–₹299/month)
- **In-App Ads**: Non-intrusive ads in free tier
- **B2B Partnerships**: Enterprise licensing for device manufacturers
- **One-time Purchases**: Storage unlock ($2.99)

## Development

### Adding a New Feature

1. Create feature branch: `git checkout -b feature/feature-name`
2. Write code following Material 3 design patterns
3. Update relevant services (OcrService, DatabaseService, etc.)
4. Test on both Android and iOS
5. Submit PR with description

### Code Style
- Follow Dart conventions (effective Dart)
- Use meaningful variable names
- No comments unless WHY is non-obvious
- Keep functions focused and single-responsibility

### Testing
```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Generate coverage report
flutter test --coverage
```

## Known Limitations

- OCR works best with English text
- Duplicate detection based on extracted text similarity
- Local database syncs to Firestore (one-way sync currently)
- Offline mode has limited functionality

## Future Roadmap

- [ ] Multi-language OCR support
- [ ] Advanced image similarity detection (ML model)
- [ ] Cloud backup and restore
- [ ] Collaborative folders (share screenshots with others)
- [ ] Custom category creation
- [ ] Advanced search filters
- [ ] Desktop app (Windows/Mac)
- [ ] Web dashboard

## Troubleshooting

### App crashes on startup
- Clear app cache: `flutter clean`
- Reinstall dependencies: `flutter pub get`
- Check Firebase config files exist

### OCR not working
- Ensure Google Play Services installed on Android
- Check photo permissions granted
- Verify image format is supported (JPEG, PNG)

### Photos not syncing
- Check Firebase connection
- Verify gallery permissions granted
- Check device storage is not full
- Restart app to trigger manual sync

## Support

For issues or feature requests, contact: allenpesigan@gmail.com

## License

Proprietary — Sweptie. All rights reserved.
