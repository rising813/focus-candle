import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../animation/extinguish_state.dart';
import '../animation/flame_state.dart';
import '../animation/melt_state.dart';
import 'candle_painter.dart';

/// Self-contained animated candle widget.
///
/// [meltProgress]    — 0→1 from Pomodoro timer (session progress).
/// [extinguishState] — driven by ExtinguishEngine in HomeScreen when
///                     the session completes.
class AnimatedCandle extends StatefulWidget {
  final double          width;
  final double          height;
  final double          meltProgress;
  final ExtinguishState extinguishState;

  const AnimatedCandle({
    super.key,
    required this.width,
    required this.height,
    required this.meltProgress,
    required this.extinguishState,
  });

  @override
  State<AnimatedCandle> createState() => _AnimatedCandleState();
}

class _AnimatedCandleState extends State<AnimatedCandle>
    with SingleTickerProviderStateMixin {
  late final Ticker       _ticker;
  final FlameNoiseEngine  _noise = FlameNoiseEngine();
  FlameState              _flameState = FlameState.idle;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    setState(() => _flameState = _noise.tick());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  widget.width,
      height: widget.height,
      child: CustomPaint(
        isComplex: true,
        painter: CandlePainter(
          flame:      _flameState,
          melt:       MeltState.fromProgress(widget.meltProgress),
          extinguish: widget.extinguishState,
        ),
      ),
    );
  }
}
