import 'package:flutter/material.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/widgets/shimmer%20loader/shimmer_loader.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final isDesktop = ResponsiveWidget.isDesktop(context);
    final cardCount = isMobile ? 3 : isDesktop ? 6 : 4;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 6),
            _buildShimmerFilters(context),
            const SizedBox(height: 18),
            _buildShimmerMovieSection(
              context,
              titleWidth: 180,
              itemCount: cardCount,
              showProgressBar: true,
            ),
            const SizedBox(height: 12),
            _buildShimmerMovieSection(
              context,
              titleWidth: 160,
              itemCount: cardCount,
            ),
            const SizedBox(height: 12),
            _buildShimmerMovieSection(
              context,
              titleWidth: 200,
              itemCount: cardCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDesktop = ResponsiveWidget.isDesktop(context);
    final iconSize = isDesktop ? 34.0 : 30.0;
    final logoSize = isDesktop ? 46.0 : 40.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ShimmerLoader(
            width: logoSize,
            height: logoSize,
            borderRadius: 10,
          ),
          const Spacer(),
          ShimmerLoader(
            width: iconSize,
            height: iconSize,
            borderRadius: iconSize / 2,
          ),
          const SizedBox(width: 8),
          ShimmerLoader(
            width: iconSize,
            height: iconSize,
            borderRadius: iconSize / 2,
          ),
          const SizedBox(width: 8),
          ShimmerLoader(
            width: iconSize,
            height: iconSize,
            borderRadius: iconSize / 2,
          ),
        ],
      ),
    );
  }

  // 📌 Filter Buttons Placeholder
  Widget _buildShimmerFilters(BuildContext context) {
    final isDesktop = ResponsiveWidget.isDesktop(context);
    final chipHeight = isDesktop ? 32.0 : 28.0;
    final chipWidth = isDesktop ? 90.0 : 70.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: ShimmerLoader(
              width: chipWidth,
              height: chipHeight,
              borderRadius: 16,
            ),
          );
        }),
      ),
    );
  }

  // 📌 Movie Section Placeholder
  Widget _buildShimmerMovieSection(
    BuildContext context, {
    required double titleWidth,
    required int itemCount,
    bool showProgressBar = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ShimmerLoader(
            width: titleWidth,
            height: 18,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: MovieCard.standardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return _movieCardPlaceholder(
                context,
                showProgressBar: showProgressBar,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _movieCardPlaceholder(
    BuildContext context, {
    bool showProgressBar = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: MovieCard.cardWidthFor(context),
      margin: const EdgeInsets.all(MovieCard.itemMargin),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 8,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  const ShimmerLoader(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                  if (showProgressBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: ShimmerLoader(
                          width: double.infinity,
                          height: 4,
                          borderRadius: 6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ShimmerLoader(
                    width: 90,
                    height: 8,
                    borderRadius: 4,
                  ),
                  const ShimmerLoader(
                    width: double.infinity,
                    height: 12,
                  ),
                  ShimmerLoader(
                    width: 120,
                    height: 8,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
