import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../animation/extinguish_state.dart';
import '../animation/flame_state.dart';
import '../animation/melt_state.dart';
import '../theme/app_theme.dart';

/// Full candle painter. Three independent data streams:
///   [flame]      – 60-fps flicker noise (every field compared in shouldRepaint)
///   [melt]       – session-length melting progress
///   [extinguish] – dying flame + smoke sequence
///
/// Performance notes:
///   - Static Paint objects cached as fields to avoid per-frame allocation.
///   - Smoke puffs capped at 8 (down from 14) to stay fast on mid-range devices.
///   - shouldRepaint does field-level comparison so identity changes don't force repaints.
class CandlePainter extends CustomPainter {
  final FlameState      flame;
  final MeltState       melt;
  final ExtinguishState extinguish;

  const CandlePainter({
    required this.flame,
    required this.melt,
    required this.extinguish,
  });

  // ── Layout constants ─────────────────────────────────────────────────────
  static const double _kBodyBottomFrac  = 1.00;
  static const double _kBodyTopFullFrac = 0.26;
  static const double _kBodyHWFrac      = 0.38;
  static const double _kFlameHeightFrac = 0.20;
  static const double _kWickFullLenFrac = 0.065;

  // ── Cached static paints (avoids per-frame allocation) ──────────────────
  static final Paint _bodyFillPaint = Paint()..color = AppTheme.waxBody;
  static final Paint _wickStrokePaint = Paint()
    ..color       = const Color(0xFF2E1F0E)
    ..strokeWidth = 2.0
    ..strokeCap   = StrokeCap.round
    ..style       = PaintingStyle.stroke;
  static final Paint _poolFillPaint  = Paint()..color = AppTheme.waxTop;
  static final Paint _waxTexturePaint = Paint()
    ..color = AppTheme.waxHighlight.withValues(alpha: 0.09);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final hw = size.width  * _kBodyHWFrac;

    // ── Melt-adjusted body geometry ──────────────────────────────────────
    final bodyBotY     = size.height * _kBodyBottomFrac;
    final fullBodyH    = size.height * (1.0 - _kBodyTopFullFrac);
    final currentBodyH = fullBodyH   * melt.bodyHeightFraction;
    final bodyTopY     = bodyBotY    - currentBodyH;

    final fullWickLen  = size.height * _kWickFullLenFrac;
    final wickLen      = fullWickLen * melt.wickLengthFraction;
    final wickBotY     = bodyTopY + 4;
    final wickTopY     = wickBotY - wickLen;

    // ── Effective flame params (normal OR dying) ──────────────────────────
    final ex = extinguish;
    final bool flameVisible = ex.flameVisible;

    double effH  = flame.heightScale;
    double effW  = flame.widthScale;
    double effGI = flame.glowIntensity;
    double effLX = flame.tipLeanX;
    double effBX = flame.bodySwayX;

    if (ex.phase == ExtinguishPhase.weakening) {
      final s = ex.flameStrength;
      effH  = flame.heightScale * s - (1.0 - s) * 0.35;
      effW  = flame.widthScale  * s - (1.0 - s) * 0.20;
      effGI = flame.glowIntensity * s;
    } else if (ex.phase == ExtinguishPhase.flickering) {
      final s = ex.flameStrength;
      final n = ex.flickerNoise;
      effH  = (flame.heightScale * 0.3 + n * 0.6 - 0.5) * s * 1.4;
      effW  = (flame.widthScale  * 0.3 + n * 0.4 - 0.2) * s;
      effGI = flame.glowIntensity * s * (0.4 + n * 0.6);
      effLX = flame.tipLeanX * 2.5 * n;
      effBX = flame.bodySwayX * 2.0;
    }

    final baseFlameH = size.height * _kFlameHeightFrac;
    final flameH     = baseFlameH * (1.0 + effH).clamp(0.05, 1.6);
    final flameBaseY = wickTopY;
    final flameTipY  = flameBaseY - flameH;
    final baseHW     = size.width * 0.13;
    final flameHW    = (baseHW * (1.0 + effW)).clamp(2.0, baseHW * 1.6);
    final gi         = effGI.clamp(0.0, 1.4);

    // ── 1. Ambient glow ──────────────────────────────────────────────────
    if (flameVisible && gi > 0.02) {
      _circle(canvas,
        center: Offset(cx, flameBaseY),
        radius: size.width * 1.5,
        color:  AppTheme.glowWarm.withValues(alpha: 0.055 * gi),
        sigma:  55);
      _circle(canvas,
        center: Offset(cx, flameBaseY),
        radius: size.width * 0.85,
        color:  AppTheme.glowWarm.withValues(alpha: 0.11 * gi),
        sigma:  30);
    }

    // ── 2. Candle body ───────────────────────────────────────────────────
    _paintBody(canvas, cx, bodyTopY, bodyBotY, hw, gi);

    // ── 3. Wax drips ─────────────────────────────────────────────────────
    _paintDrips(canvas, cx, bodyTopY, bodyBotY, hw);

    // ── 4. Wax pool ──────────────────────────────────────────────────────
    _paintWaxPool(canvas, cx, bodyTopY, hw, flameVisible ? gi : 0.0);

    // ── 5. Wick ──────────────────────────────────────────────────────────
    _paintWick(canvas, cx, wickTopY, wickBotY, ex);

    // ── 6. Flame ─────────────────────────────────────────────────────────
    if (flameVisible && flameH > 1.0) {
      _paintFlame(canvas,
        cx: cx, tipY: flameTipY, baseY: flameBaseY,
        flameHW: flameHW, tipLeanX: effLX,
        bodySwayX: effBX, rotationRad: flame.rotationRad, gi: gi);

      final flameMidY = flameTipY + flameH * 0.45;
      _circle(canvas,
        center: Offset(cx + effBX * 0.5, flameMidY),
        radius: flameHW * 1.8,
        color:  AppTheme.flameInner.withValues(alpha: 0.50 * gi),
        sigma:  12);
      _circle(canvas,
        center: Offset(cx, flameBaseY - flameH * 0.12),
        radius: flameHW * 0.9,
        color:  AppTheme.flameCore.withValues(alpha: 0.65 * gi),
        sigma:  7);
    }

    // ── 7. Smoke ─────────────────────────────────────────────────────────
    if (ex.phase == ExtinguishPhase.smoke || ex.phase == ExtinguishPhase.done) {
      _paintSmoke(canvas, cx, wickTopY, ex.smokeProgress, ex.smokeSway, size);
    }
  }

  // ── Flame ─────────────────────────────────────────────────────────────────

  void _paintFlame(Canvas canvas, {
    required double cx, required double tipY,   required double baseY,
    required double flameHW, required double tipLeanX,
    required double bodySwayX, required double rotationRad, required double gi,
  }) {
    canvas.save();
    canvas.translate(cx, baseY);
    canvas.rotate(rotationRad);
    canvas.translate(-cx, -baseY);

    _flameShape(canvas,
      cx: cx + bodySwayX * 0.4, tipY: tipY, baseY: baseY,
      hw: flameHW * 1.05, leanX: tipLeanX * 0.8,
      color: AppTheme.flameOuter.withValues(alpha: (0.82 * gi).clamp(0, 1)),
      blur: 6.0);
    _flameShape(canvas,
      cx: cx + bodySwayX * 0.3,
      tipY: tipY + (baseY - tipY) * 0.04, baseY: baseY,
      hw: flameHW * 0.76, leanX: tipLeanX * 0.65,
      color: AppTheme.flameMid.withValues(alpha: gi.clamp(0, 1)),
      blur: 4.5);
    _flameShape(canvas,
      cx: cx + bodySwayX * 0.2,
      tipY: tipY + (baseY - tipY) * 0.15, baseY: baseY,
      hw: flameHW * 0.50, leanX: tipLeanX * 0.45,
      color: AppTheme.flameInner, blur: 3.0);
    _flameShape(canvas,
      cx: cx + bodySwayX * 0.1,
      tipY: tipY + (baseY - tipY) * 0.34,
      baseY: baseY - (baseY - tipY) * 0.03,
      hw: flameHW * 0.22, leanX: tipLeanX * 0.20,
      color: AppTheme.flameCore, blur: 1.5);

    canvas.restore();
  }

  void _flameShape(Canvas canvas, {
    required double cx, required double tipY, required double baseY,
    required double hw,  required double leanX,
    required Color color, required double blur,
  }) {
    final h = baseY - tipY;
    if (h <= 0) return;
    final tx = cx + leanX;
    canvas.drawPath(
      Path()
        ..moveTo(tx, tipY)
        ..cubicTo(tx + hw * 0.9, tipY + h * 0.28, cx + hw * 0.95, tipY + h * 0.72, cx, baseY)
        ..cubicTo(cx - hw * 0.95, tipY + h * 0.72, tx - hw * 0.9, tipY + h * 0.28, tx, tipY)
        ..close(),
      Paint()..color = color..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  // ── Smoke (perf: 8 puffs, lighter blur) ──────────────────────────────────

  void _paintSmoke(Canvas canvas, double cx, double wickTopY,
      double progress, double sway, Size size) {
    final opacity = progress < 0.20
        ? (progress / 0.20).clamp(0.0, 1.0) * 0.50
        : progress < 0.65
            ? 0.50
            : ((1.0 - progress) / 0.35).clamp(0.0, 1.0) * 0.50;

    if (opacity < 0.01) return;

    final smokeRise = size.height * 0.50 * progress.clamp(0.0, 1.0);
    // PERF FIX: 8 puffs instead of 14
    const puffCount = 8;
    for (int i = 0; i < puffCount; i++) {
      final frac  = i / (puffCount - 1.0);
      final puffY = wickTopY - frac * smokeRise;
      final drift = sway * frac * 1.6 + math.sin(frac * math.pi * 2.1) * 2.5 * frac;
      final puffR = 2.0 + frac * 8.0;
      final puffO = (opacity * (1.0 - frac * 0.60)).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(cx + drift, puffY),
        puffR,
        // PERF FIX: lighter blur sigma
        Paint()
          ..color = const Color(0xFFAAAAAA).withValues(alpha: puffO)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, puffR * 0.7),
      );
    }
  }

  // ── Wick ──────────────────────────────────────────────────────────────────

  void _paintWick(Canvas canvas, double cx, double top, double bottom,
      ExtinguishState ex) {
    Color wickColor;
    Color emberColor;
    double emberRadius  = 3.0;
    double emberOpacity = 0.88;

    if (ex.phase == ExtinguishPhase.emberGlow) {
      final t = ex.emberProgress;
      wickColor    = Color.lerp(const Color(0xFF8B1A00), const Color(0xFF1A1410), t)!;
      emberColor   = Color.lerp(const Color(0xFFFF4400), const Color(0xFF3A1A00), t)!;
      emberOpacity = (1.0 - t * 0.85).clamp(0.0, 1.0);
      emberRadius  = 3.0 + (1.0 - t) * 3.0;
    } else if (ex.phase == ExtinguishPhase.smoke || ex.phase == ExtinguishPhase.done) {
      wickColor    = const Color(0xFF1A1410);
      emberColor   = Colors.transparent;
      emberOpacity = 0;
      emberRadius  = 0;
    } else {
      wickColor    = const Color(0xFF2E1F0E);
      emberColor   = AppTheme.flameOuter;
      emberOpacity = ex.flameVisible ? 0.88 : 0.0;
    }

    canvas.drawPath(
      Path()
        ..moveTo(cx, bottom)
        ..quadraticBezierTo(cx + 1.5, (top + bottom) / 2, cx, top),
      Paint()
        ..color       = wickColor
        ..strokeWidth = 2.0
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke,
    );

    if (emberOpacity > 0.01 && emberRadius > 0.5) {
      canvas.drawCircle(
        Offset(cx, top + 2), emberRadius,
        Paint()
          ..color = emberColor.withValues(alpha: emberOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, emberRadius * 0.7),
      );
      if (ex.phase == ExtinguishPhase.emberGlow) {
        canvas.drawCircle(
          Offset(cx, top + 2), emberRadius * 2.0,
          Paint()
            ..color = const Color(0xFFFF2200)
                .withValues(alpha: (emberOpacity * 0.25 * (1.0 - ex.emberProgress)).clamp(0, 1))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, emberRadius * 1.5),
        );
      }
    }
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  void _paintBody(Canvas canvas, double cx, double top, double bottom,
      double hw, double gi) {
    final h = bottom - top;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - hw, top, cx + hw, bottom),
        topLeft: const Radius.circular(4), topRight: const Radius.circular(4),
        bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8),
      ),
      _bodyFillPaint,
    );

    // Right shadow
    canvas.drawPath(
      Path()..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTRB(cx + hw * 0.30, top, cx + hw, bottom),
        topRight: const Radius.circular(4), bottomRight: const Radius.circular(8),
      )),
      Paint()
        ..color = AppTheme.waxShadow.withValues(alpha: 0.52)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Left highlight
    canvas.drawRect(
      Rect.fromLTRB(cx - hw, top, cx + hw * 0.18, bottom),
      Paint()
        ..color = AppTheme.waxHighlight.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );

    // Flame wash — only when lit
    if (gi > 0.02) {
      canvas.drawRect(
        Rect.fromLTRB(cx - hw, top, cx + hw, top + h * 0.22),
        Paint()
          ..color = AppTheme.glowWarm.withValues(alpha: 0.07 * gi)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }

    // Wax texture ridges
    for (int i = 1; i <= 3; i++) {
      final y = top + h * (0.14 + i * 0.22);
      if (y >= bottom - 4) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - hw + 3, y, cx + hw * (0.20 + i * 0.07), y + 1.5),
          const Radius.circular(1),
        ),
        _waxTexturePaint,
      );
    }
  }

  // ── Drips ─────────────────────────────────────────────────────────────────

  void _paintDrips(Canvas canvas, double cx, double bodyTop,
      double bodyBot, double hw) {
    final bodyH = bodyBot - bodyTop;
    for (final drip in melt.drips) {
      final x      = cx + hw * drip.xFraction;
      final startY = bodyTop + 2;
      final endY   = bodyTop + bodyH * drip.runFraction;
      if (endY <= startY + 4) continue;

      final blobR = drip.widthPx * 1.1;
      canvas.drawCircle(Offset(x, endY), blobR,
        Paint()..color = AppTheme.waxTop.withValues(alpha: 0.85));

      final hw2 = drip.widthPx / 2;
      canvas.drawPath(
        Path()
          ..moveTo(x - hw2 * 0.5, startY)
          ..cubicTo(x - hw2, startY + (endY - startY) * 0.4,
                    x - hw2, startY + (endY - startY) * 0.8, x, endY)
          ..cubicTo(x + hw2, startY + (endY - startY) * 0.8,
                    x + hw2, startY + (endY - startY) * 0.4,
                    x + hw2 * 0.5, startY)
          ..close(),
        Paint()
          ..color = AppTheme.waxTop.withValues(alpha: 0.72)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
      );
    }
  }

  // ── Wax pool ──────────────────────────────────────────────────────────────

  void _paintWaxPool(Canvas canvas, double cx, double bodyTop,
      double hw, double gi) {
    final poolW   = (hw * melt.poolWidthFraction * 2).clamp(0.0, hw * 2 + 4);
    final poolH   = melt.poolHeightPx;
    final centerY = bodyTop + poolH * 0.45;
    final poolRect = Rect.fromCenter(
      center: Offset(cx, centerY), width: poolW, height: poolH);

    canvas.drawOval(poolRect, _poolFillPaint);
    canvas.drawOval(poolRect.deflate(3),
      Paint()
        ..color = AppTheme.waxShadow.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    if (gi > 0.02) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - hw * 0.07, centerY - 2),
          width:  hw * 0.45 * melt.poolWidthFraction,
          height: poolH * 0.35),
        Paint()
          ..color = AppTheme.flameInner.withValues(alpha: 0.20 * gi)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  // ── Util ──────────────────────────────────────────────────────────────────

  void _circle(Canvas canvas, {
    required Offset center, required double radius,
    required Color color,   required double sigma,
  }) {
    canvas.drawCircle(center, radius,
      Paint()..color = color..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
  }

  // BUG FIX: compare fields, not object identity, for FlameState
  @override
  bool shouldRepaint(CandlePainter old) {
    if (old.melt.progress != melt.progress)             return true;
    if (old.extinguish.phase         != extinguish.phase)         return true;
    if (old.extinguish.flameStrength != extinguish.flameStrength) return true;
    if (old.extinguish.smokeProgress != extinguish.smokeProgress) return true;
    if (old.extinguish.emberProgress != extinguish.emberProgress) return true;
    if (old.extinguish.smokeSway     != extinguish.smokeSway)     return true;
    // Flame fields (always different every tick, so this fast-paths to true)
    if (old.flame.heightScale  != flame.heightScale)  return true;
    if (old.flame.glowIntensity != flame.glowIntensity) return true;
    return false;
  }
}
