
/// Immutable snapshot of the candle's melt state at a given [progress].
///
/// [progress] runs 0.0 (full candle, session start) → 1.0 (fully melted, done).
/// All geometry values are pre-computed fractions ready for the painter to use.
class MeltState {
  /// Session progress 0.0 – 1.0.
  final double progress;

  /// Fraction of the candle body height remaining (1.0 → 0.05).
  /// Never reaches 0 so the flame always has a stub to sit on.
  final double bodyHeightFraction;

  /// Half-width of the wax pool ellipse, as a fraction of body half-width.
  /// Grows from 0.85 → 1.05 (pool overflows edges slightly at end).
  final double poolWidthFraction;

  /// Height of the wax pool ellipse in pixels (absolute, not a fraction).
  final double poolHeightPx;

  /// List of wax drips. Each drip is a [_Drip] describing its x-offset,
  /// how far it has run down the body, and its visual width.
  final List<WaxDrip> drips;

  /// Wick visible length fraction (1.0 → 0.35 as candle melts).
  final double wickLengthFraction;

  const MeltState({
    required this.progress,
    required this.bodyHeightFraction,
    required this.poolWidthFraction,
    required this.poolHeightPx,
    required this.drips,
    required this.wickLengthFraction,
  });

  static const MeltState initial = MeltState(
    progress: 0,
    bodyHeightFraction: 1.0,
    poolWidthFraction: 0.85,
    poolHeightPx: 14,
    drips: [],
    wickLengthFraction: 1.0,
  );

  /// Compute a [MeltState] from a 0–1 [progress] value and a seeded RNG
  /// so drip positions are deterministic for the same progress level.
  factory MeltState.fromProgress(double progress) {
    final p = progress.clamp(0.0, 1.0);

    // Body shrinks from 100% to 15% of original height.
    final bodyH = 1.0 - p * 0.85;

    // Pool widens and deepens.
    final poolW = 0.85 + p * 0.22;
    final poolH = 14.0 + p * 28.0; // 14px → 42px

    // Wick shortens (still visible at end).
    final wickLen = 1.0 - p * 0.65;

    // Drips: start appearing after 8% progress, more appear over time.
    // Use a seeded Random so positions are stable across rebuilds.
    final drips = _computeDrips(p);

    return MeltState(
      progress: p,
      bodyHeightFraction: bodyH,
      poolWidthFraction: poolW,
      poolHeightPx: poolH,
      drips: drips,
      wickLengthFraction: wickLen,
    );
  }

  static List<WaxDrip> _computeDrips(double p) {
    if (p < 0.08) return [];

    // Drip "seeds" — fixed x-offsets relative to body half-width.
    // New drips unlock at specific progress thresholds.
    const dripSeeds = [
      _DripSeed(xFrac: -0.55, threshold: 0.08, widthPx: 3.5),
      _DripSeed(xFrac:  0.70, threshold: 0.14, widthPx: 2.8),
      _DripSeed(xFrac: -0.20, threshold: 0.22, widthPx: 4.2),
      _DripSeed(xFrac:  0.40, threshold: 0.31, widthPx: 3.0),
      _DripSeed(xFrac: -0.75, threshold: 0.42, widthPx: 2.5),
      _DripSeed(xFrac:  0.15, threshold: 0.55, widthPx: 3.8),
      _DripSeed(xFrac: -0.45, threshold: 0.68, widthPx: 2.2),
    ];

    final result = <WaxDrip>[];
    for (final seed in dripSeeds) {
      if (p < seed.threshold) continue;
      // How far has this drip progressed since it started?
      final dripAge = ((p - seed.threshold) / (1.0 - seed.threshold)).clamp(0.0, 1.0);
      // Drips run down at most 60% of the body height.
      final runFrac = dripAge * 0.60;
      result.add(WaxDrip(
        xFraction: seed.xFrac,
        runFraction: runFrac,
        widthPx: seed.widthPx,
      ));
    }
    return result;
  }
}

/// A single wax drip descriptor.
class WaxDrip {
  /// X position as fraction of body half-width (−1 = left edge, +1 = right edge).
  final double xFraction;

  /// How far down the body the drip has run (0 = top, 1 = bottom of body).
  final double runFraction;

  /// Visual stroke width in pixels.
  final double widthPx;

  const WaxDrip({
    required this.xFraction,
    required this.runFraction,
    required this.widthPx,
  });
}

class _DripSeed {
  final double xFrac;
  final double threshold;
  final double widthPx;
  const _DripSeed({
    required this.xFrac,
    required this.threshold,
    required this.widthPx,
  });
}
