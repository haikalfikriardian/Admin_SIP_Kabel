
# Admin Panel SIPKABEL

This is a Flutter web admin panel for SIPKABEL. It is designed to be run as a web application.

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (ensure it's added to your PATH)
- Chrome or another supported web browser

### Install Dependencies
Open a terminal in the project root and run:

```sh
flutter pub get
```

### Run the App (Web)
To start the app in your default browser:

```sh
flutter run -d chrome
```

Or, to build for web release:

```sh
flutter build web
```

The output will be in the `build/web` directory.

## Project Structure
- `lib/` — Main application code
- `web/` — Web entry point and static files
- `assets/` — Images and other assets

## Notes
- This project is web-only. Mobile and desktop folders have been removed for a cleaner setup.

---
For more Flutter documentation, visit the [official docs](https://docs.flutter.dev/).
