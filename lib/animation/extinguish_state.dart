import 'dart:math' as math;

/// The phase the extinguish sequence is in.
enum ExtinguishPhase {
  /// Timer still running — no extinguish in progress.
  none,

  /// Flame weakening: height and glow reduce over ~1.2 s.
  weakening,

  /// Irregular death flicker: random spasms over ~1.0 s.
  flickering,

  /// Flame has gone out. Wick glows red-orange for ~0.6 s.
  emberGlow,

  /// Thin smoke trail rises and fades over ~3 s.
  smoke,

  /// Everything finished.
  done,
}

/// Immutable snapshot of the extinguish animation at one moment.
class ExtinguishState {
  final ExtinguishPhase phase;

  // ── Flame die-out fields (used during weakening / flickering) ────────────

  /// 1.0 = full-strength flame, 0.0 = extinguished.
  final double flameStrength;

  /// Extra random scale applied during the death flicker (0–1).
  final double flickerNoise;

  // ── Ember fields (used during emberGlow) ─────────────────────────────────

  /// 0.0 → 1.0 over the emberGlow phase; used to fade the red-hot wick.
  final double emberProgress;

  // ── Smoke fields (used during smoke) ────────────────────────────────────

  /// 0.0 → 1.0 over the smoke phase.
  final double smokeProgress;

  /// Horizontal sway offset of the smoke trail (updated each frame).
  final double smokeSway;

  const ExtinguishState({
    required this.phase,
    required this.flameStrength,
    required this.flickerNoise,
    required this.emberProgress,
    required this.smokeProgress,
    required this.smokeSway,
  });

  static const ExtinguishState idle = ExtinguishState(
    phase: ExtinguishPhase.none,
    flameStrength: 1.0,
    flickerNoise: 0.0,
    emberProgress: 0.0,
    smokeProgress: 0.0,
    smokeSway: 0.0,
  );

  bool get isActive => phase != ExtinguishPhase.none && phase != ExtinguishPhase.done;
  bool get flameVisible =>
      phase == ExtinguishPhase.none ||
      phase == ExtinguishPhase.weakening ||
      phase == ExtinguishPhase.flickering;
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine
// ─────────────────────────────────────────────────────────────────────────────

/// Drives the extinguish sequence frame-by-frame.
///
/// Call [trigger()] when the timer hits zero.
/// Call [tick(dt)] every frame; it returns the current [ExtinguishState].
class ExtinguishEngine {
  ExtinguishEngine() : _rng = math.Random();

  final math.Random _rng;

  // Phase durations (seconds)
  static const double _kWeakenDuration  = 1.20;
  static const double _kFlickerDuration = 1.00;
  static const double _kEmberDuration   = 0.70;
  static const double _kSmokeDuration   = 3.20;

  ExtinguishPhase _phase = ExtinguishPhase.none;
  double _phaseElapsed   = 0.0; // seconds elapsed in current phase

  // Noise oscillators for organic movement
  double _smokeSwayPhase = 0.0;
  double _flickerPhase   = 0.0;

  // Cached flicker noise to avoid too-rapid changes
  double _cachedFlicker = 0.0;
  double _flickerTimer  = 0.0;
  static const double _flickerUpdateRate = 0.045; // seconds between flicker jumps

  bool get isDone => _phase == ExtinguishPhase.done;
  bool get isIdle => _phase == ExtinguishPhase.none;

  /// Start the extinguish sequence. Safe to call multiple times (ignored if already running).
  void trigger() {
    if (_phase != ExtinguishPhase.none) return;
    _phase        = ExtinguishPhase.weakening;
    _phaseElapsed = 0.0;
  }

  /// Advance by [dt] seconds. Returns the current [ExtinguishState].
  ExtinguishState tick(double dt) {
    if (_phase == ExtinguishPhase.none) return ExtinguishState.idle;
    if (_phase == ExtinguishPhase.done) {
      return const ExtinguishState(
        phase: ExtinguishPhase.done,
        flameStrength: 0,
        flickerNoise: 0,
        emberProgress: 1,
        smokeProgress: 1,
        smokeSway: 0,
      );
    }

    _phaseElapsed += dt;

    switch (_phase) {
      case ExtinguishPhase.weakening:
        return _tickWeakening();
      case ExtinguishPhase.flickering:
        return _tickFlickering(dt);
      case ExtinguishPhase.emberGlow:
        return _tickEmber();
      case ExtinguishPhase.smoke:
        return _tickSmoke(dt);
      case ExtinguishPhase.none:
      case ExtinguishPhase.done:
        return ExtinguishState.idle;
    }
  }

  // ── Phase tickers ─────────────────────────────────────────────────────────

  ExtinguishState _tickWeakening() {
    final t = (_phaseElapsed / _kWeakenDuration).clamp(0.0, 1.0);
    // Ease-in: strength drops quickly at first, then levels before flicker
    final strength = (1.0 - _easeIn(t) * 0.55).clamp(0.0, 1.0);

    if (_phaseElapsed >= _kWeakenDuration) _nextPhase();

    return ExtinguishState(
      phase: ExtinguishPhase.weakening,
      flameStrength: strength,
      flickerNoise: 0,
      emberProgress: 0,
      smokeProgress: 0,
      smokeSway: 0,
    );
  }

  ExtinguishState _tickFlickering(double dt) {
    final t = (_phaseElapsed / _kFlickerDuration).clamp(0.0, 1.0);

    // Strength continues dropping to zero
    final strength = (0.45 - _easeIn(t) * 0.45).clamp(0.0, 1.0);

    // Irregular flicker: update at a human-perceptible rate, not every frame
    _flickerTimer += dt;
    _flickerPhase += dt * 14.0; // fast oscillator
    if (_flickerTimer >= _flickerUpdateRate) {
      _flickerTimer = 0;
      _cachedFlicker = _rng.nextDouble();
    }
    // Combine smooth oscillation with the random jump
    final noise = (math.sin(_flickerPhase) * 0.3 + _cachedFlicker * 0.7)
        .clamp(0.0, 1.0);

    if (_phaseElapsed >= _kFlickerDuration) _nextPhase();

    return ExtinguishState(
      phase: ExtinguishPhase.flickering,
      flameStrength: strength,
      flickerNoise: noise,
      emberProgress: 0,
      smokeProgress: 0,
      smokeSway: 0,
    );
  }

  ExtinguishState _tickEmber() {
    final t = (_phaseElapsed / _kEmberDuration).clamp(0.0, 1.0);
    if (_phaseElapsed >= _kEmberDuration) _nextPhase();

    return ExtinguishState(
      phase: ExtinguishPhase.emberGlow,
      flameStrength: 0,
      flickerNoise: 0,
      emberProgress: t,
      smokeProgress: 0,
      smokeSway: 0,
    );
  }

  ExtinguishState _tickSmoke(double dt) {
    final t = (_phaseElapsed / _kSmokeDuration).clamp(0.0, 1.0);

    _smokeSwayPhase += dt * 0.9; // slow, organic sway
    final sway = math.sin(_smokeSwayPhase) * 4.0 +
        math.sin(_smokeSwayPhase * 2.3) * 1.5;

    if (_phaseElapsed >= _kSmokeDuration) _nextPhase();

    return ExtinguishState(
      phase: ExtinguishPhase.smoke,
      flameStrength: 0,
      flickerNoise: 0,
      emberProgress: 1,
      smokeProgress: t,
      smokeSway: sway,
    );
  }

  void _nextPhase() {
    _phaseElapsed = 0.0;
    switch (_phase) {
      case ExtinguishPhase.weakening:
        _phase = ExtinguishPhase.flickering;
      case ExtinguishPhase.flickering:
        _phase = ExtinguishPhase.emberGlow;
      case ExtinguishPhase.emberGlow:
        _phase = ExtinguishPhase.smoke;
      case ExtinguishPhase.smoke:
        _phase = ExtinguishPhase.done;
      default:
        _phase = ExtinguishPhase.done;
    }
  }

  // ── Easing ────────────────────────────────────────────────────────────────
  static double _easeIn(double t) => t * t;

  /// Reset so the sequence can be triggered again (e.g. after timer reset).
  void reset() {
    _phase        = ExtinguishPhase.none;
    _phaseElapsed = 0.0;
    _smokeSwayPhase = 0.0;
    _flickerPhase   = 0.0;
    _cachedFlicker  = 0.0;
    _flickerTimer   = 0.0;
  }
}
