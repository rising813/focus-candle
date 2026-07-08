import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../animation/extinguish_state.dart';
import '../models/app_settings.dart';
import '../models/session_store.dart';
import '../services/sound_manager.dart';
import '../services/vibration_service.dart';
import '../theme/app_theme.dart';
import '../utils/pomodoro_controller.dart';
import '../widgets/animated_candle.dart';
import '../widgets/session_dots.dart';
import '../widgets/timer_controls.dart';
import '../widgets/timer_display.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings initialSettings;
  const HomeScreen({super.key, required this.initialSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  late AppSettings       _settings;
  late PomodoroController _pomodoro;

  bool   _isRunning  = false;
  Timer? _secondTimer;

  // Extinguish animation
  final ExtinguishEngine _extinguishEngine = ExtinguishEngine();
  ExtinguishState _extinguishState = ExtinguishState.idle;
  late final Ticker _extinguishTicker;
  Duration? _prevElapsed;

  // Session stats
  int _todayCount = 0;
  int _streak     = 0;

  double get _candleMelt =>
      _pomodoro.mode == SessionMode.focus ? _pomodoro.meltProgress : 0.0;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _pomodoro = _buildController();
    _extinguishTicker = createTicker(_onExtinguishTick);
    // Stats already loaded in main(); just pull from store
    _todayCount = SessionStore.instance.todayCount;
    _streak     = SessionStore.instance.currentStreak;
  }

  PomodoroController _buildController() => PomodoroController(
    focusSeconds:      _settings.focusMinutes      * 60,
    shortBreakSeconds: _settings.shortBreakMinutes * 60,
    longBreakSeconds:  _settings.longBreakMinutes  * 60,
    longBreakAfter:    _settings.longBreakAfter,
  );

  @override
  void dispose() {
    _secondTimer?.cancel();
    _extinguishTicker.dispose();
    super.dispose();
  }

  // ── Extinguish ────────────────────────────────────────────────────────────

  void _onExtinguishTick(Duration elapsed) {
    final prev   = _prevElapsed;
    final dt     = prev == null
        ? 1 / 60.0
        : (elapsed - prev).inMicroseconds / 1e6;
    _prevElapsed = elapsed;
    final next   = _extinguishEngine.tick(dt.clamp(0.0, 0.05));
    if (mounted) setState(() => _extinguishState = next);
    if (_extinguishEngine.isDone) _extinguishTicker.stop();
  }

  void _triggerExtinguish() {
    _extinguishEngine.trigger();
    _prevElapsed = null;
    if (!_extinguishTicker.isActive) _extinguishTicker.start();
  }

  // FIX: setState-safe reset — no nested setState calls
  void _clearExtinguish() {
    _extinguishEngine.reset();
    _extinguishTicker.stop();
    _prevElapsed    = null;
    _extinguishState = ExtinguishState.idle;
  }

  // ── Timer control ─────────────────────────────────────────────────────────

  void _start() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    if (_settings.soundEnabled && _pomodoro.mode == SessionMode.focus) {
      SoundManager.instance.startCrackle();
    }
    if (_settings.vibrationEnabled) VibrationService.instance.light();

    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Capture mode BEFORE tick() transitions it
      final wasInFocus = _pomodoro.mode == SessionMode.focus;
      final completed  = _pomodoro.tick();
      setState(() {}); // refresh remaining / meltProgress
      if (completed) _onSessionComplete(wasFocus: wasInFocus);
    });
  }

  // FIX: _pause() never calls setState itself — callers do
  void _stopTimer() {
    _secondTimer?.cancel();
    _secondTimer = null;
  }

  void _pause() {
    _stopTimer();
    SoundManager.instance.stopCrackle();
    if (_settings.vibrationEnabled) VibrationService.instance.light();
    if (mounted) setState(() => _isRunning = false);
  }

  void _reset() {
    _stopTimer();
    SoundManager.instance.stopCrackle();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _clearExtinguish();
        _pomodoro.reset();
      });
    }
  }

  // FIX: _hardReset() is now purely state-mutation, called inside setState by caller
  void _applyHardReset() {
    _stopTimer();
    SoundManager.instance.stopCrackle();
    _isRunning = false;
    _clearExtinguish();
    _pomodoro.hardReset();
  }

  void _onSessionComplete({required bool wasFocus}) {
    _stopTimer();
    if (mounted) setState(() => _isRunning = false);

    if (_settings.soundEnabled) SoundManager.instance.playChime();
    if (_settings.vibrationEnabled) VibrationService.instance.sessionComplete();

    if (wasFocus) {
      SessionStore.instance.recordSession().then((_) {
        if (mounted) {
          setState(() {
            _todayCount = SessionStore.instance.todayCount;
            _streak     = SessionStore.instance.currentStreak;
          });
        }
      });
      _triggerExtinguish();

      // Auto-clear extinguish after sequence completes + buffer
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isRunning) {
          setState(() => _clearExtinguish());
        }
      });
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> _openSettings() async {
    // Pause without vibration feedback (navigating away)
    _stopTimer();
    SoundManager.instance.stopCrackle();
    if (mounted) setState(() => _isRunning = false);

    final result = await Navigator.of(context).push<AppSettings>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SettingsScreen(settings: _settings),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );

    if (result != null && mounted) {
      // FIX: _applyHardReset() mutates fields directly; safe inside setState
      setState(() {
        _settings = result;
        SoundManager.instance.soundEnabled = result.soundEnabled;
        _applyHardReset();
        _pomodoro = _buildController();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final candleH = screenH * 0.46;
    final candleW = candleH * (160.0 / 440.0);
    final isFocus = _pomodoro.mode == SessionMode.focus;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // FIX: Positioned must be direct child of Stack.
          // RepaintBoundary wraps the inner child, not Positioned.
          Positioned(
            top:  screenH * 0.01,
            left: screenW / 2 - screenW * 0.80,
            child: RepaintBoundary(
              child: IgnorePointer(
                child: Container(
                  width:  screenW * 1.60,
                  height: screenW * 1.60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.glowWarm.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'candle',
                          style: AppTheme.labelStyle.copyWith(
                            fontSize: 10,
                            letterSpacing: 6,
                            color: AppTheme.textMuted.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openSettings,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AppTheme.textMuted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Candle — RepaintBoundary isolates 60-fps flame from outer tree
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      child: AnimatedCandle(
                        width:           candleW,
                        height:          candleH,
                        meltProgress:    _candleMelt,
                        extinguishState: _extinguishState,
                      ),
                    ),
                  ),
                ),

                TimerDisplay(
                  timeString: PomodoroController.format(_pomodoro.remaining),
                  mode:       _pomodoro.mode,
                ),

                const SizedBox(height: 20),

                if (isFocus)
                  SessionDots(
                    completedInCycle: _pomodoro.completedInCycle,
                    longBreakAfter:   _settings.longBreakAfter,
                    todayCount:       _todayCount,
                    streak:           _streak,
                  ),

                const SizedBox(height: 22),

                TimerControls(
                  isRunning: _isRunning,
                  mode:      _pomodoro.mode,
                  onStart:   _start,
                  onPause:   _pause,
                  onReset:   _reset,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
