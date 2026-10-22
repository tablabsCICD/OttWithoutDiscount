import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';
import 'package:provider/provider.dart';

class FeatureTourTarget extends StatefulWidget {
  const FeatureTourTarget({
    super.key,
    required this.id,
    required this.child,
  });

  final FeatureTourStepId id;
  final Widget child;

  @override
  State<FeatureTourTarget> createState() => _FeatureTourTargetState();
}

class _FeatureTourTargetState extends State<FeatureTourTarget> {
  OnboardingTourProvider? _tourProvider;
  int _lastRefreshRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _tourProvider = context.read<OnboardingTourProvider>();
    } catch (_) {
      _tourProvider = null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishRect());
  }

  @override
  void didUpdateWidget(covariant FeatureTourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishRect());
  }

  @override
  void dispose() {
    _tourProvider?.unregisterTarget(widget.id);
    super.dispose();
  }

  void _publishRect() {
    if (!mounted) return;
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;

      final origin = renderObject.localToGlobal(Offset.zero);
      final rect = origin & renderObject.size;
      _tourProvider?.registerTarget(widget.id, rect);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final refreshRevision = context.select<OnboardingTourProvider, int>(
      (provider) => provider.targetRefreshRevision,
    );
    if (_lastRefreshRevision != refreshRevision) {
      _lastRefreshRevision = refreshRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _publishRect());
    }

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) {
        context.read<OnboardingTourProvider>().trackFeatureClicked(widget.id);
      },
      child: widget.child,
    );
  }
}

class FeatureTourOverlay extends StatelessWidget {
  const FeatureTourOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingTourProvider>(
      builder: (context, tour, _) {
        if (!tour.isActive) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final step = tour.currentStep;
        final screenSize = MediaQuery.of(context).size;
        final rect = tour.rectFor(step.id);
        final spotlight = rect?.inflate(10);
        final tooltipWidth = math.min(screenSize.width - 32, 360.0);
        final tooltipTop = _tooltipTop(
          screenSize: screenSize,
          spotlight: spotlight,
        );
        final tooltipLeft = ((spotlight?.center.dx ?? screenSize.width / 2) -
                tooltipWidth / 2)
            .clamp(16.0, screenSize.width - tooltipWidth - 16)
            .toDouble();

        return Semantics(
          label: '${step.title}. ${step.description}',
          liveRegion: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      spotlight: spotlight,
                      overlayColor: Colors.black.withOpacity(0.74),
                      borderColor: theme.primaryColor,
                    ),
                  ),
                ),
              ),
              if (spotlight != null)
                Positioned.fromRect(
                  rect: spotlight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.95),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.32),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: tooltipTop,
                left: tooltipLeft,
                width: tooltipWidth,
                child: _TourCard(
                  step: step,
                  index: tour.currentIndex,
                  count: tour.activeSteps.length,
                  onNext: tour.next,
                  onSkip: tour.skip,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _tooltipTop({
    required Size screenSize,
    required Rect? spotlight,
  }) {
    const cardHeight = 230.0;
    if (spotlight == null) {
      return (screenSize.height - cardHeight) / 2;
    }

    final below = spotlight.bottom + 18;
    if (below + cardHeight <= screenSize.height - 16) return below;

    final above = spotlight.top - cardHeight - 18;
    if (above >= 16) return above;

    return (screenSize.height - cardHeight - 16)
        .clamp(16.0, screenSize.height)
        .toDouble();
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onSkip,
  });

  final FeatureTourStep step;
  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = index == count - 1;

    return FocusTraversalGroup(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.title,
                      style: TextStyle(
                        color: theme.canvasColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${index + 1}/$count',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.description,
                style: TextStyle(
                  color: theme.canvasColor.withOpacity(0.76),
                  fontSize: 14,
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: theme.canvasColor),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    autofocus: true,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onNext,
                    child: Text(isLast ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.spotlight,
    required this.overlayColor,
    required this.borderColor,
  });

  final Rect? spotlight;
  final Color overlayColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    if (spotlight == null) {
      canvas.drawPath(fullPath, Paint()..color = overlayColor);
      return;
    }

    final spotlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          spotlight!,
          const Radius.circular(18),
        ),
      );
    final path = Path.combine(
      PathOperation.difference,
      fullPath,
      spotlightPath,
    );
    canvas.drawPath(path, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderColor != borderColor;
  }
}
