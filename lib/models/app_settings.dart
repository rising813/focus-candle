import 'package:shared_preferences/shared_preferences.dart';

/// All user-configurable settings, persisted via SharedPreferences.
class AppSettings {
  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kFocusMinutes      = 'focus_minutes';
  static const _kShortBreakMinutes = 'short_break_minutes';
  static const _kLongBreakMinutes  = 'long_break_minutes';
  static const _kLongBreakAfter    = 'long_break_after';
  static const _kSoundEnabled      = 'sound_enabled';
  static const _kVibrationEnabled  = 'vibration_enabled';

  // ── Defaults ──────────────────────────────────────────────────────────────
  static const int defaultFocusMinutes      = 25;
  static const int defaultShortBreakMinutes = 5;
  static const int defaultLongBreakMinutes  = 15;
  static const int defaultLongBreakAfter    = 4;

  // ── Fields ────────────────────────────────────────────────────────────────
  int  focusMinutes;
  int  shortBreakMinutes;
  int  longBreakMinutes;
  int  longBreakAfter;
  bool soundEnabled;
  bool vibrationEnabled;

  AppSettings({
    this.focusMinutes      = defaultFocusMinutes,
    this.shortBreakMinutes = defaultShortBreakMinutes,
    this.longBreakMinutes  = defaultLongBreakMinutes,
    this.longBreakAfter    = defaultLongBreakAfter,
    this.soundEnabled      = true,
    this.vibrationEnabled  = true,
  });

  // ── Persistence ───────────────────────────────────────────────────────────

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      focusMinutes:      prefs.getInt(_kFocusMinutes)      ?? defaultFocusMinutes,
      shortBreakMinutes: prefs.getInt(_kShortBreakMinutes) ?? defaultShortBreakMinutes,
      longBreakMinutes:  prefs.getInt(_kLongBreakMinutes)  ?? defaultLongBreakMinutes,
      longBreakAfter:    prefs.getInt(_kLongBreakAfter)    ?? defaultLongBreakAfter,
      soundEnabled:      prefs.getBool(_kSoundEnabled)     ?? true,
      vibrationEnabled:  prefs.getBool(_kVibrationEnabled) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFocusMinutes,      focusMinutes);
    await prefs.setInt(_kShortBreakMinutes, shortBreakMinutes);
    await prefs.setInt(_kLongBreakMinutes,  longBreakMinutes);
    await prefs.setInt(_kLongBreakAfter,    longBreakAfter);
    await prefs.setBool(_kSoundEnabled,     soundEnabled);
    await prefs.setBool(_kVibrationEnabled, vibrationEnabled);
  }

  AppSettings copyWith({
    int?  focusMinutes,
    int?  shortBreakMinutes,
    int?  longBreakMinutes,
    int?  longBreakAfter,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) => AppSettings(
    focusMinutes:      focusMinutes      ?? this.focusMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes:  longBreakMinutes  ?? this.longBreakMinutes,
    longBreakAfter:    longBreakAfter    ?? this.longBreakAfter,
    soundEnabled:      soundEnabled      ?? this.soundEnabled,
    vibrationEnabled:  vibrationEnabled  ?? this.vibrationEnabled,
  );
}
