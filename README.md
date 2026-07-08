# Focus Candle

A premium Pomodoro timer with an animated candle aesthetic.

## Target Versions

- Flutter Stable **3.44.x**
- Dart **3.5+**
- Android Gradle Plugin **8.5.2**
- Gradle **8.7**
- Kotlin **1.9.24**
- Java **17**

Android build files use the **modern Flutter Plugin DSL** (`dev.flutter.flutter-gradle-plugin`
via `settings.gradle.kts`) — no deprecated `apply from: ".../app_plugin_loader.gradle"`.

## Requirements

- Flutter SDK ≥ 3.44.0
- Java 17 (Android Studio's bundled JDK works)
- Android SDK (minSdk 21, targetSdk 34, compileSdk 34)

## Build

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on a connected device / emulator
flutter run

# 3. Debug APK
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk

# 4. Release APK (uses debug signing by default — see below)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# 5. Release App Bundle (Play Store)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

`android/local.properties` is **not** included — Flutter tooling generates it automatically
on the first `flutter pub get` / `flutter run`, pointing `flutter.sdk` at your local Flutter
installation. No manual edits needed.

## Project Structure

```
lib/
├── main.dart                    # Entry point, service init
├── animation/
│   ├── extinguish_state.dart    # Dying flame state machine + noise engine
│   ├── flame_state.dart         # 60-fps flicker noise engine
│   └── melt_state.dart          # Session-length melt geometry
├── models/
│   ├── app_settings.dart        # User settings + SharedPreferences persistence
│   └── session_store.dart       # Session history + streak tracking
├── screens/
│   ├── home_screen.dart         # Main UI + Pomodoro state
│   └── settings_screen.dart     # Settings panel
├── services/
│   ├── sound_manager.dart       # Audio fade engine (audioplayers)
│   └── vibration_service.dart   # Haptic feedback wrapper
├── theme/
│   └── app_theme.dart           # Colors, typography, ThemeData
├── utils/
│   └── pomodoro_controller.dart # Pure-Dart session state machine
└── widgets/
    ├── animated_candle.dart     # Ticker + CustomPaint wrapper
    ├── candle_painter.dart      # Full candle CustomPainter
    ├── session_dots.dart        # Cycle progress dots + stats
    ├── timer_controls.dart      # Start/Pause/Reset pills
    └── timer_display.dart       # Serif timer + mode label

android/
├── settings.gradle.kts          # Modern Flutter Plugin DSL (pluginManagement block)
├── build.gradle.kts             # Root project config
├── gradle.properties            # JVM args, AndroidX flags
├── gradle/wrapper/
│   └── gradle-wrapper.properties  # Gradle 8.7
└── app/
    ├── build.gradle.kts         # App module — plugins{} block, no apply-from
    └── src/main/
        ├── AndroidManifest.xml
        ├── kotlin/.../MainActivity.kt
        └── res/                 # Icons, splash, styles
```

## Production Keystore (Release)

Replace the debug signing config in `android/app/build.gradle.kts`:

```kotlin
signingConfigs {
    create("release") {
        storeFile = file("/path/to/release.keystore")
        storePassword = "your_store_password"
        keyAlias = "your_key_alias"
        keyPassword = "your_key_password"
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
    }
}
```
