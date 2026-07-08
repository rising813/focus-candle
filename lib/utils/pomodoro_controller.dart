/// Which kind of session is currently active.
enum SessionMode { focus, shortBreak, longBreak }

extension SessionModeLabel on SessionMode {
  String get label {
    switch (this) {
      case SessionMode.focus:      return 'focus';
      case SessionMode.shortBreak: return 'short break';
      case SessionMode.longBreak:  return 'long break';
    }
  }
}

/// Pure-Dart Pomodoro state machine.
///
/// Owns the counters and transition logic; no Flutter / timer imports.
/// HomeScreen holds the [dart:async] Timer and calls [tick()] every second.
class PomodoroController {
  PomodoroController({
    required this.focusSeconds,
    required this.shortBreakSeconds,
    required this.longBreakSeconds,
    required this.longBreakAfter,
  }) : _remaining = focusSeconds;

  final int focusSeconds;
  final int shortBreakSeconds;
  final int longBreakSeconds;
  final int longBreakAfter;

  SessionMode _mode       = SessionMode.focus;
  int         _remaining;
  int         _focusDoneThisCycle = 0; // resets after long break
  int         _totalFocusDone     = 0;
  bool        _sessionJustEnded   = false;

  // ── Accessors ─────────────────────────────────────────────────────────────

  SessionMode get mode      => _mode;
  int  get remaining        => _remaining;
  int  get focusDoneToday   => _totalFocusDone; // updated by caller via recordSession
  int  get completedInCycle => _focusDoneThisCycle;
  bool get sessionJustEnded => _sessionJustEnded;

  /// Progress 0→1 for candle melt (only meaningful during focus sessions).
  double get meltProgress {
    if (_mode != SessionMode.focus) return 0.0;
    final elapsed = focusSeconds - _remaining;
    return (elapsed / focusSeconds).clamp(0.0, 1.0);
  }

  int get totalForCurrentMode {
    switch (_mode) {
      case SessionMode.focus:      return focusSeconds;
      case SessionMode.shortBreak: return shortBreakSeconds;
      case SessionMode.longBreak:  return longBreakSeconds;
    }
  }

  // ── Commands ──────────────────────────────────────────────────────────────

  /// Advance by one second. Returns true if the session just completed.
  bool tick() {
    _sessionJustEnded = false;
    if (_remaining > 0) {
      _remaining--;
      return false;
    }
    // Reached zero — transition
    _sessionJustEnded = true;
    _advance();
    return true;
  }

  void reset() {
    _remaining  = totalForCurrentMode;
    _sessionJustEnded = false;
  }

  void hardReset() {
    _mode       = SessionMode.focus;
    _remaining  = focusSeconds;
    _focusDoneThisCycle = 0;
    _sessionJustEnded   = false;
  }

  void skipToNext() => _advance();

  // ── Internals ─────────────────────────────────────────────────────────────

  void _advance() {
    switch (_mode) {
      case SessionMode.focus:
        _focusDoneThisCycle++;
        _totalFocusDone++;
        if (_focusDoneThisCycle >= longBreakAfter) {
          _mode = SessionMode.longBreak;
          _remaining = longBreakSeconds;
          _focusDoneThisCycle = 0;
        } else {
          _mode = SessionMode.shortBreak;
          _remaining = shortBreakSeconds;
        }
      case SessionMode.shortBreak:
      case SessionMode.longBreak:
        _mode = SessionMode.focus;
        _remaining = focusSeconds;
    }
  }

  // ── Format ────────────────────────────────────────────────────────────────

  static String format(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds  % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
