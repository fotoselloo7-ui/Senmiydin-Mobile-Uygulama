import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Lets the gesture area around a piece of content ask its [HeartBurst] to play.
class HeartBurstController {
  VoidCallback? _play;

  /// Plays the heart from the start (a second double tap restarts it).
  void play() => _play?.call();
}

/// The short heart that grows, holds and fades over content that was just liked: about 700 ms, nothing else (no
/// confetti). It is decoration only: it takes no touches and screen readers skip it (the like itself belongs to the real
/// like button). With "remove animations" turned on the heart simply fades without moving.
class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key, required this.controller, this.size = 84});

  final HeartBurstController controller;
  final double size;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  // Grow in (the first ~200 ms), settle, hold, then fade out over the last ~230 ms.
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: .55,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.14,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 14,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: .94,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 28,
    ),
  ]);
  static final _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 12,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 56),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 32,
    ),
  ]);

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    widget.controller._play = _play;
  }

  @override
  void didUpdateWidget(covariant HeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._play = null;
      widget.controller._play = _play;
    }
  }

  void _play() {
    if (mounted) _animation.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller._play = null;
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) {
      // Not yet played, or played out: nothing in the tree at all.
      if (_animation.isDismissed || _animation.isCompleted) {
        return const SizedBox.shrink();
      }
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      return ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: _opacity.evaluate(_animation).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: still ? 1 : _scale.evaluate(_animation),
              child: Icon(
                Icons.favorite_rounded,
                key: const Key('heart-burst'),
                size: widget.size,
                color: AppColors.encounterPink,
                shadows: const [
                  Shadow(
                    color: Color(0x40000000),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The touch language of social content in one place: a single tap opens the content, a double tap likes it with a
/// [HeartBurst] over the area. Without [onLike] there is no double-tap recognizer at all, so a plain tap area never
/// waits for a second tap. Only passive content belongs inside (text, photos): buttons keep their own taps outside.
class DoubleTapHeart extends StatefulWidget {
  const DoubleTapHeart({
    super.key,
    required this.child,
    this.onTap,
    this.onLike,
    this.heartSize = 76,
  });

  final Widget child;

  /// Runs after the double-tap window closed without a second tap (so a double tap never opens the content first).
  final VoidCallback? onTap;

  /// A double tap. The area plays the heart whatever the callback decides (liking again is a no-op, not an unlike).
  final VoidCallback? onLike;
  final double heartSize;

  @override
  State<DoubleTapHeart> createState() => _DoubleTapHeartState();
}

class _DoubleTapHeartState extends State<DoubleTapHeart> {
  final _burst = HeartBurstController();

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onDoubleTap: widget.onLike == null
        ? null
        : () {
            _burst.play();
            widget.onLike!();
          },
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.onLike != null)
          Positioned.fill(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Center(
                child: HeartBurst(controller: _burst, size: widget.heartSize),
              ),
            ),
          ),
      ],
    ),
  );
}
