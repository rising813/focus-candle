import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_settings.dart';
import 'models/session_store.dart';
import 'screens/home_screen.dart';
import 'services/sound_manager.dart';
import 'services/vibration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parallel init of all services
  await Future.wait([
    SoundManager.instance.init(),
    VibrationService.instance.init(),
    SessionStore.instance.load(),
  ]);

  final settings = await AppSettings.load();

  // Sync sound manager with persisted setting
  SoundManager.instance.soundEnabled = settings.soundEnabled;

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(FocusCandleApp(settings: settings));
}

class FocusCandleApp extends StatefulWidget {
  final AppSettings settings;
  const FocusCandleApp({super.key, required this.settings});

  @override
  State<FocusCandleApp> createState() => _FocusCandleAppState();
}

class _FocusCandleAppState extends State<FocusCandleApp> {
  @override
  void dispose() {
    SoundManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF141414),
          primary: Color(0xFFFFB340),
          onSurface: Color(0xFFEDE6D6),
        ),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: HomeScreen(initialSettings: widget.settings),
    );
  }
}
