# sequence

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

++++++++++++++++++++++++++++++++++++++++++++++++++

1. python3 scripts/sync_splash_color.py
2. dart run flutter_native_splash:create
   ++++++++++++++++++++++++++++++++++++++++++++++++++

# List all iOS devices (including simulators)

xcrun xctrace list devices

1. flutter run --release -d 00008030-001179D922A1802E
2. flutter run --release -d f1d66e4f91b72e51e204554659e9609fcc76c9cb (Amitav's
   iPhone)
3. flutter run --release -d 6E6C554-7D37-406F-B597-47FB0FC3A4BE (13 Pro Max
   Simulator)
4. flutter clean
5. cd ios
6. rm -rf Pods
7. rm Podfile.lock
8. cd ..
9. flutter pub get
10. cd ios
11. pod install
12. cd ..
13. flutter run --release
