import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Thin wrapper around vibration so HomeScreen never imports the package directly.
class VibrationService {
  VibrationService._();
  static final VibrationService instance = VibrationService._();

  bool _hasVibrator = false;
  bool _checked = false;

  Future<void> init() async {
    if (_checked) return;
    _checked = true;
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
    } catch (e) {
      debugPrint('[VibrationService] init error: $e');
      _hasVibrator = false;
    }
  }

  /// Short tap feedback (session start/pause).
  Future<void> light() async {
    if (!_hasVibrator) return;
    try {
      Vibration.vibrate(duration: 30, amplitude: 60);
    } catch (_) {}
  }

  /// Double-pulse for session complete.
  Future<void> sessionComplete() async {
    if (!_hasVibrator) return;
    try {
      Vibration.vibrate(pattern: [0, 80, 120, 120], amplitudes: [0, 128, 0, 200]);
    } catch (_) {}
  }
}
