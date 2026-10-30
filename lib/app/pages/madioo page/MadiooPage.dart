import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ott/app/core/constant/image_constant.dart';

class MadiooPage extends StatefulWidget {
  const MadiooPage({super.key, this.useParentScroll = false});

  final bool useParentScroll;

  @override
  State<MadiooPage> createState() => _MadiooPageState();
}

class _MadiooPageState extends State<MadiooPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final int barCount = 5;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 🎵 Animated sound bars
  Widget _buildWaveBars(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(barCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = sin((_controller.value * 2 * pi) + index);
            double height = 10 + (value.abs() * 30);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        /// 📻 Radio Icon with glow
          /*  Container(
            padding: const EdgeInsets.all(20),
            child: Hero(
              tag: "logo",
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {},
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    ImageConstant.madiooLogo,
                    width: 75,
                    height: 75,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
 */
          /// 🎧 Title
          Text(
            "Madioo is Coming Soon",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: theme.canvasColor,
            ),
          ),

          const SizedBox(height: 5),

          /// 📄 Subtitle
          Text(
            "Streaming Hindi songs...\nYour vibe, anytime 🎶",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: theme.canvasColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 60),

          /// 🎵 Animated Wave Bars
          _buildWaveBars(theme.primaryColor),
        ],
      ),
    );
  }
}
