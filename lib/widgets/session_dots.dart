import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Progress dots for the current Pomodoro cycle, plus today/streak stats.
class SessionDots extends StatelessWidget {
  final int completedInCycle;
  final int longBreakAfter;
  final int todayCount;
  final int streak;

  const SessionDots({
    super.key,
    required this.completedInCycle,
    required this.longBreakAfter,
    required this.todayCount,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cycle dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(longBreakAfter, (i) {
            final filled = i < completedInCycle;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? AppTheme.flameMid.withValues(alpha: 0.85)
                    : AppTheme.textDim,
              ),
            );
          }),
        ),

        const SizedBox(height: 10),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stat(label: 'today', value: '$todayCount'),
            _divider(),
            _stat(label: 'streak', value: '${streak}d'),
          ],
        ),
      ],
    );
  }

  Widget _stat({required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14,
            color: AppTheme.textPrimary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 3,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    color: AppTheme.separator,
  );
}
