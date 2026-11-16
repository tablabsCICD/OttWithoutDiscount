import 'package:flutter/material.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class AboutFilmytellScreen extends StatelessWidget {
  const AboutFilmytellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final selectedThemeData = themeProvider.getTheme;
    final subText = theme.hintColor;
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(title: lang.aboutFilmytell),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🎬 HERO
            Text(
              lang.profileAboutHeadline,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),

            Text(
              lang.profileAboutSubheadline,
              style: theme.textTheme.bodyMedium?.copyWith(color: subText),
            ),

            const SizedBox(height: 16),

            /// 🔴 BADGES
            Wrap(
              spacing: 8,
              children: [
                _Badge(lang.profilePayPerView, selectedThemeData.primaryColor),
                _Badge(lang.profileNoAds, selectedThemeData.primaryColor),
                _Badge(lang.profileExclusive, selectedThemeData.primaryColor),
              ],
            ),

            const SizedBox(height: 24),

            /// 📝 INTRO
            Text(
              lang.profileAboutIntro,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 24),

            /// ⭐ FEATURES
            _title(context, lang.profileWhyFilmytell),

            const SizedBox(height: 12),

            _FeatureTile(
              icon: Icons.payments_outlined,
              title: lang.profilePayPerView,
              subtitle: lang.profilePayPerViewSubtitle,
              color: selectedThemeData.primaryColor,
            ),
            _FeatureTile(
              icon: Icons.block,
              title: lang.profileNoAds,
              subtitle: lang.profileNoAdsSubtitle,
              color: selectedThemeData.primaryColor,
            ),
            _FeatureTile(
              icon: Icons.public,
              title: lang.profileExclusiveContent,
              subtitle: lang.profileExclusiveContentSubtitle,
              color: selectedThemeData.primaryColor,
            ),

            const SizedBox(height: 24),

            /// 🎞 CONTENT
            _title(context, lang.profileWatch),

            const SizedBox(height: 10),

            ResponsiveWidget.isDesktop(context)
                ? Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Chip(lang.moviesLabel),
                      _Chip(lang.profileWebSeries),
                      _Chip(lang.minSeries),
                      _Chip(lang.profileRegional),
                    ],
                  )
                : Column(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Chip(lang.moviesLabel),
                          _Chip(lang.profileWebSeries),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Chip(lang.minSeries),
                          _Chip(lang.profileRegional),
                        ],
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            /// 👥 CARDS
            Row(
              children: [
                Expanded(
                  child: _MiniCard(
                    title: lang.profileViewers,
                    content: lang.profileViewersContent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniCard(
                    title: lang.profileCreators,
                    content: lang.profileCreatorsContent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            /// 🎯 CTA
            Center(
              child: Text(
                'Cinema Ka Naya Ghar',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selectedThemeData.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

/// =======================
/// COMPONENTS
/// =======================

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.15),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
      ),
      child: Text(label),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String content;

  const _MiniCard({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}
