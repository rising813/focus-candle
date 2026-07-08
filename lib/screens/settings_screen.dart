import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/sound_manager.dart';
import '../theme/app_theme.dart';

/// Full-screen settings panel. Slides up from bottom.
/// Returns updated [AppSettings] when popped, or null if unchanged.
class SettingsScreen extends StatefulWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings.copyWith();
  }

  Future<void> _save() async {
    await _s.save();
    // Sync sound manager
    SoundManager.instance.soundEnabled = _s.soundEnabled;
    if (mounted) Navigator.of(context).pop(_s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'settings',
                      style: AppTheme.labelStyle.copyWith(
                        fontSize: 12,
                        letterSpacing: 6,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  // Done button
                  GestureDetector(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'done',
                        style: AppTheme.buttonStyle.copyWith(
                          color: AppTheme.flameMid,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const _Separator(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  // ── Timer durations ─────────────────────────────────────
                  _SectionHeader(label: 'timer'),
                  _DurationRow(
                    label: 'Focus',
                    value: _s.focusMinutes,
                    min: 1, max: 90,
                    onChanged: (v) => setState(() => _s.focusMinutes = v),
                  ),
                  _DurationRow(
                    label: 'Short break',
                    value: _s.shortBreakMinutes,
                    min: 1, max: 30,
                    onChanged: (v) => setState(() => _s.shortBreakMinutes = v),
                  ),
                  _DurationRow(
                    label: 'Long break',
                    value: _s.longBreakMinutes,
                    min: 5, max: 60,
                    onChanged: (v) => setState(() => _s.longBreakMinutes = v),
                  ),
                  _DurationRow(
                    label: 'Long break after',
                    value: _s.longBreakAfter,
                    min: 2, max: 8,
                    suffix: 'sessions',
                    onChanged: (v) => setState(() => _s.longBreakAfter = v),
                  ),

                  const SizedBox(height: 8),
                  const _Separator(),

                  // ── Sound & haptics ─────────────────────────────────────
                  _SectionHeader(label: 'experience'),
                  _ToggleRow(
                    label: 'Candle crackle & chime',
                    value: _s.soundEnabled,
                    onChanged: (v) => setState(() => _s.soundEnabled = v),
                  ),
                  _ToggleRow(
                    label: 'Vibration',
                    value: _s.vibrationEnabled,
                    onChanged: (v) => setState(() => _s.vibrationEnabled = v),
                  ),

                  const SizedBox(height: 8),
                  const _Separator(),

                  // ── About ───────────────────────────────────────────────
                  _SectionHeader(label: 'about'),
                  const _AboutRow(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 24),
    color: AppTheme.separator,
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 4,
        color: AppTheme.textDim,
      ),
    ),
  );
}

class _DurationRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _DurationRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = 'min',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTheme.settingLabelStyle),
          ),
          // Decrement
          _StepButton(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: AppTheme.settingValueStyle,
            ),
          ),
          const SizedBox(width: 8),
          // Increment
          _StepButton(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(
            color: active
                ? AppTheme.flameMid.withValues(alpha: 0.3)
                : AppTheme.textDim,
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: active ? AppTheme.flameMid : AppTheme.textDim,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.settingLabelStyle)),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value
                    ? AppTheme.flameMid.withValues(alpha: 0.25)
                    : AppTheme.textDim.withValues(alpha: 0.3),
                border: Border.all(
                  color: value
                      ? AppTheme.flameMid.withValues(alpha: 0.5)
                      : AppTheme.textDim,
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? AppTheme.flameMid : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Focus Candle  v1.0.0',
              style: AppTheme.settingLabelStyle.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
