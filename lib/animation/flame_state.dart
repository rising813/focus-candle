import 'dart:math' as math;

/// Immutable snapshot of every flame parameter at a single point in time.
/// The painter reads this; the noise engine writes it.
class FlameState {
  /// Fractional change in total flame height. Range roughly -0.18 … +0.18.
  final double heightScale;

  /// Fractional change in flame half-width. Range roughly -0.15 … +0.15.
  final double widthScale;

  /// Lean offset of the flame tip in canvas units (positive = right).
  final double tipLeanX;

  /// Brightness multiplier applied to glow opacities. Range 0.7 … 1.3.
  final double glowIntensity;

  /// Subtle whole-flame rotation in radians. Range -0.06 … +0.06.
  final double rotationRad;

  /// Independent sway of the flame body midpoint.
  final double bodySwayX;

  const FlameState({
    required this.heightScale,
    required this.widthScale,
    required this.tipLeanX,
    required this.glowIntensity,
    required this.rotationRad,
    required this.bodySwayX,
  });

  static const FlameState idle = FlameState(
    heightScale: 0,
    widthScale: 0,
    tipLeanX: 0,
    glowIntensity: 1,
    rotationRad: 0,
    bodySwayX: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Noise Engine
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight value-noise engine used to produce smooth, non-repeating
/// flame flicker without any external packages.
///
/// Works by summing several sine oscillators at incommensurable frequencies
/// (no common integer ratio), then interpolating toward random target values
/// to introduce micro-turbulence.
class FlameNoiseEngine {
  FlameNoiseEngine() : _rng = math.Random();

  final math.Random _rng;

  // Per-dimension oscillator phases (advance each frame)
  double _phaseH  = 0; // height
  double _phaseW  = 0; // width
  double _phaseTX = 0; // tip-x lean
  double _phaseG  = 0; // glow
  double _phaseR  = 0; // rotation
  double _phaseBX = 0; // body sway

  // Turbulence targets (jumped randomly every few frames)
  double _turbH  = 0;
  double _turbW  = 0;
  double _turbTX = 0;

  int _turbCounter = 0;
  static const int _turbInterval = 7; // jump target every N frames

  // ── Frequencies (Hz at 60 fps → rad/frame = freq * 2π / 60) ────────────
  // Chosen to be irrational multiples so they never phase-lock.
  static const double _fH  = 1.7;   // height primary
  static const double _fH2 = 3.1;   // height harmonic
  static const double _fW  = 2.3;   // width
  static const double _fW2 = 4.7;   // width harmonic
  static const double _fTX = 1.3;   // tip lean
  static const double _fTX2= 2.9;
  static const double _fG  = 1.1;   // glow
  static const double _fG2 = 3.7;
  static const double _fR  = 0.9;   // rotation (slowest)
  static const double _fBX = 1.5;   // body sway

  static double _toRad(double hz) => hz * 2 * math.pi / 60.0;

  /// Advance the engine by one frame and return a new [FlameState].
  FlameState tick() {
    // ── advance phases ─────────────────────────────────────────────────────
    _phaseH  += _toRad(_fH);
    _phaseW  += _toRad(_fW);
    _phaseTX += _toRad(_fTX);
    _phaseG  += _toRad(_fG);
    _phaseR  += _toRad(_fR);
    _phaseBX += _toRad(_fBX);

    // ── update turbulence targets ──────────────────────────────────────────
    _turbCounter++;
    if (_turbCounter >= _turbInterval) {
      _turbCounter = 0;
      _turbH  = (_rng.nextDouble() - 0.5) * 0.10;
      _turbW  = (_rng.nextDouble() - 0.5) * 0.08;
      _turbTX = (_rng.nextDouble() - 0.5) * 4.0;
    }

    // ── compose signals ────────────────────────────────────────────────────
    // Each channel = primary oscillator + weaker harmonic + turbulence nudge
    final h = _layered(_phaseH, _fH2, 0.18, 0.07) + _turbH;
    final w = _layered(_phaseW, _fW2, 0.15, 0.06) + _turbW;
    final tx = _layered(_phaseTX, _fTX2, 3.0, 1.2) + _turbTX;
    final g  = 1.0 + _layered(_phaseG, _fG2, 0.18, 0.08);
    final r  = _layered(_phaseR, _fR * 2.1, 0.055, 0.020);
    final bx = math.sin(_phaseBX) * 2.5;

    return FlameState(
      heightScale:  h.clamp(-0.22, 0.22),
      widthScale:   w.clamp(-0.20, 0.20),
      tipLeanX:     tx.clamp(-6.0, 6.0),
      glowIntensity: g.clamp(0.65, 1.40),
      rotationRad:  r.clamp(-0.07, 0.07),
      bodySwayX:    bx,
    );
  }

  /// Sum two sine waves at [primaryPhase] and a derived harmonic.
  double _layered(
    double primaryPhase,
    double harmonicFreq,
    double primaryAmp,
    double harmonicAmp,
  ) {
    return math.sin(primaryPhase) * primaryAmp +
           math.sin(primaryPhase * (harmonicFreq / _fH)) * harmonicAmp;
  }
}
