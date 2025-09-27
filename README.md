# Instagram Follow Manager

A Flutter application for managing your Instagram following and followers lists with local caching and background synchronization.

## Features

- **Multiple Account Support**: Manage multiple Instagram accounts from a single app
- **Local Caching**: Store followers and following data locally using SQLite for fast access
- **Background Sync**: Automatically sync data in the background to keep your lists up to date
- **Search & Filter**: Search through your followers and following lists
- **Profile Information**: View detailed profile information including profile pictures, bio, and stats
- **Local Management**: Add/remove followers and following locally with background sync
- **Secure Storage**: Credentials are stored securely using Flutter Secure Storage

## Screenshots

The app includes:
- Home screen with account selection and overview
- Followers list with search and detailed profiles
- Following list with search and management options
- Account management for adding/removing Instagram accounts

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android device or emulator / iOS simulator

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd igfollowmgr
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── database/
│   └── database_helper.dart          # SQLite database operations
├── models/
│   ├── instagram_account.dart        # Instagram account model
│   ├── instagram_user.dart          # Instagram user model
│   └── profile.dart                 # Profile model
├── providers/
│   └── instagram_provider.dart      # State management
├── screens/
│   ├── home_screen.dart             # Main home screen
│   ├── followers_screen.dart        # Followers list screen
│   ├── following_screen.dart        # Following list screen
│   └── account_management_screen.dart # Account management
├── services/
│   ├── instagram_api_service.dart   # Instagram API integration
│   └── sync_service.dart            # Background sync service
└── main.dart                        # App entry point
```

## Database Schema

The app uses SQLite with the following tables:

- **instagram_accounts**: Stores Instagram account credentials and session data
- **profiles**: Caches profile information for accounts
- **followers**: Stores follower data with relationship timestamps
- **following**: Stores following data with relationship timestamps
- **sync_queue**: Tracks pending sync operations

## Key Features

### Account Management
- Add multiple Instagram accounts
- Secure credential storage
- Account switching
- Sync status tracking

### Data Synchronization
- Initial data fetch when adding accounts
- Background periodic sync
- Manual sync option
- Sync queue for pending operations

### User Interface
- Material Design 3
- Instagram-inspired color scheme
- Responsive design
- Search functionality
- Profile detail views

### Local Operations
- Add/remove followers locally
- Add/remove following locally
- Background sync of local changes
- Offline data access

## Security Considerations

- Credentials are stored using Flutter Secure Storage
- Session tokens are managed securely
- No credentials are logged or exposed
- Local database is encrypted

## Limitations

- Instagram API limitations may affect sync frequency
- Rate limiting is implemented to prevent API abuse
- Some features may require active Instagram sessions
- Background sync depends on device capabilities

## Dependencies

- **sqflite**: SQLite database
- **provider**: State management
- **dio**: HTTP client
- **cached_network_image**: Image caching
- **flutter_secure_storage**: Secure credential storage
- **workmanager**: Background tasks
- **intl**: Date formatting
- **json_annotation**: JSON serialization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This app is for personal use only. Please respect Instagram's Terms of Service and API usage policies. The app is not affiliated with Instagram or Meta.