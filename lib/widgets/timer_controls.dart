import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/pomodoro_controller.dart';

/// Primary/secondary pill controls. Adapts label to session mode.
class TimerControls extends StatelessWidget {
  final bool isRunning;
  final SessionMode mode;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  const TimerControls({
    super.key,
    required this.isRunning,
    required this.mode,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLabel = isRunning
        ? 'pause'
        : mode == SessionMode.focus ? 'begin' : 'start break';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: primaryLabel,
          onTap: isRunning ? onPause : onStart,
          isPrimary: true,
        ),
        const SizedBox(height: 14),
        _Pill(
          label: 'reset',
          onTap: onReset,
          isPrimary: false,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _Pill({required this.label, required this.onTap, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width:  isPrimary ? 160 : 90,
        height: isPrimary ? 52  : 38,
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.flameMid.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: isPrimary
                ? AppTheme.flameMid.withValues(alpha: 0.35)
                : AppTheme.textMuted.withValues(alpha: 0.35),
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTheme.buttonStyle.copyWith(
            color: isPrimary
                ? AppTheme.textPrimary.withValues(alpha: 0.90)
                : AppTheme.textMuted,
            letterSpacing: isPrimary ? 4 : 3,
          ),
        ),
      ),
    );
  }
}
