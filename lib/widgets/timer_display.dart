import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/pomodoro_controller.dart';

/// Large serif timer + mode label (focus / short break / long break).
class TimerDisplay extends StatelessWidget {
  final String timeString;
  final SessionMode mode;

  const TimerDisplay({
    super.key,
    required this.timeString,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mode.label.toUpperCase(),
          style: AppTheme.labelStyle.copyWith(
            fontSize: 9,
            letterSpacing: 5,
            color: AppTheme.textMuted.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        Text(timeString, style: AppTheme.timerStyle),
      ],
    );
  }
}
