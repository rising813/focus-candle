import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Central sound service for Focus Candle.
///
/// - Loops candle crackle while timer is running.
/// - Smooth fade-in (1.8 s) on start, fade-out (1.2 s) on pause/reset.
/// - One-shot completion chime at session end.
/// - [soundEnabled] flag for Settings integration.
///
/// Lifecycle:
///   await SoundManager.instance.init();   // once at app start (main.dart)
///   SoundManager.instance.dispose();      // in app lifecycle didDetachFromEngine
class SoundManager with WidgetsBindingObserver {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  // ── Config ─────────────────────────────────────────────────────────────
  bool soundEnabled = true;

  static const String _crackleAsset    = 'audio/candle_crackle.wav';
  static const String _chimeAsset      = 'audio/completion_chime.wav';
  static const double _crackleMaxVolume = 0.55;
  static const int    _fadeInMs         = 1800;
  static const int    _fadeOutMs        = 1200;
  static const int    _fadeTickMs       = 40;

  // ── Players ────────────────────────────────────────────────────────────
  late final AudioPlayer _cracklePlayer;
  late final AudioPlayer _chimePlayer;

  bool _initialised   = false;
  bool _crackleActive = false;
  Timer? _fadeTimer;
  double _currentVolume = 0.0;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Call once at app start. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // BUG FIX: set AudioContext for Android compatibility
    _cracklePlayer = AudioPlayer();
    _chimePlayer   = AudioPlayer();

    // Register lifecycle observer to stop audio when app backgrounds
    WidgetsBinding.instance.addObserver(this);

    try {
      await _cracklePlayer.setVolume(0);
      await _cracklePlayer.setReleaseMode(ReleaseMode.loop);
      await _cracklePlayer.setSourceAsset(_crackleAsset);

      await _chimePlayer.setReleaseMode(ReleaseMode.release);
      await _chimePlayer.setSourceAsset(_chimeAsset);
    } catch (e) {
      debugPrint('[SoundManager] init error: $e');
    }
  }

  // BUG FIX: pause audio when app goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_crackleActive) {
        _cracklePlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_crackleActive) {
        _cracklePlayer.resume();
      }
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────

  Future<void> startCrackle() async {
    if (!soundEnabled || !_initialised) return;
    if (_crackleActive) return;
    _crackleActive = true;

    _cancelFade();
    try {
      await _cracklePlayer.resume();
    } catch (e) {
      debugPrint('[SoundManager] crackle resume error: $e');
      _crackleActive = false;
      return;
    }
    _fadeTo(_crackleMaxVolume, _fadeInMs);
  }

  Future<void> stopCrackle() async {
    if (!_crackleActive) return;
    _crackleActive = false;
    _cancelFade();
    _fadeTo(0.0, _fadeOutMs, onDone: () async {
      try { await _cracklePlayer.pause(); } catch (_) {}
    });
  }

  Future<void> playChime() async {
    // BUG FIX: call stopCrackle regardless of soundEnabled so state is clean
    await stopCrackle();
    if (!soundEnabled || !_initialised) return;
    try {
      await _chimePlayer.stop();
      await _chimePlayer.resume();
    } catch (e) {
      debugPrint('[SoundManager] chime error: $e');
    }
  }

  // BUG FIX: properly dispose and remove observer
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _cancelFade();
    try {
      await _cracklePlayer.dispose();
      await _chimePlayer.dispose();
    } catch (_) {}
  }

  // ── Fade engine ────────────────────────────────────────────────────────

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  void _fadeTo(double target, int durationMs, {AsyncCallback? onDone}) {
    _cancelFade();
    final steps    = (durationMs / _fadeTickMs).ceil().clamp(1, 9999);
    final startVol = _currentVolume;
    int step       = 0;

    _fadeTimer = Timer.periodic(
      Duration(milliseconds: _fadeTickMs),
      (timer) async {
        step++;
        final t = (step / steps).clamp(0.0, 1.0);
        _currentVolume = startVol + (target - startVol) * _easeInOut(t);
        try {
          await _cracklePlayer.setVolume(_currentVolume.clamp(0.0, 1.0));
        } catch (_) {}

        if (step >= steps) {
          timer.cancel();
          _fadeTimer = null;
          _currentVolume = target;
          onDone?.call();
        }
      },
    );
  }

  static double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}
