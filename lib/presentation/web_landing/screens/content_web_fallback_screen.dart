import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/constant/app_constant.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/core/network/api_helper.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/shorts%20page/component/ShortsPlayerPage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/shorts_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/getContentResponse.dart';
import 'package:ott/data/models/shorts.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';

class ContentWebFallbackScreen extends StatefulWidget {
  const ContentWebFallbackScreen({
    super.key,
    required this.contentId,
    this.contentType = DeepLinkContentType.movie,
    this.initialContent,
  });

  final int contentId;
  final DeepLinkContentType contentType;
  final Content? initialContent;

  @override
  State<ContentWebFallbackScreen> createState() =>
      _ContentWebFallbackScreenState();
}

class _ContentWebFallbackScreenState extends State<ContentWebFallbackScreen> {
  Content? _content;
  ShortDetailModel? _shortDetail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _content = widget.initialContent;
      _isLoading = false;
    } else {
      _fetchContentDetails();
    }
  }

  Future<void> _fetchContentDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.contentType == DeepLinkContentType.short ||
          widget.contentType == DeepLinkContentType.miniSeries) {
        final shortProvider =
            Provider.of<ShortProvider>(context, listen: false);
        await shortProvider.fetchShortDetail(widget.contentId, 1);
        final detail = shortProvider.shortDetail;
        if (detail != null && detail.id > 0) {
          if (mounted) {
            setState(() {
              _shortDetail = detail;
              _content = detail.toShareContent();
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Fetch standard content
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      final fetched = await dashboardProvider.getContentById(widget.contentId);
      if (fetched != null && fetched.id != null && fetched.id! > 0) {
        if (mounted) {
          setState(() {
            _content = fetched;
            _isLoading = false;
          });
        }
        return;
      }

      // Fallback direct API query if provider failed
      final directUrl = ApiConstant.getVideoById(widget.contentId, 1);
      final response = await ApiHelper().getApi(directUrl);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final contentResponse = GetContentResponse.fromJson(responseBody);
        if (contentResponse.success == true &&
            contentResponse.data?.contentList != null) {
          if (mounted) {
            setState(() {
              _content = contentResponse.data!.contentList!;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Content could not be loaded.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to connect. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  bool get _isIOS {
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    if (kIsWeb) {
      final ua = (Uri.base.queryParameters['platform'] ?? '').toLowerCase();
      if (ua == 'ios' || ua == 'iphone' || ua == 'ipad') return true;
    }
    return false;
  }

  bool get _isAndroid {
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    if (kIsWeb) {
      final ua = (Uri.base.queryParameters['platform'] ?? '').toLowerCase();
      if (ua == 'android') return true;
    }
    return false;
  }

  Uri get _universalUrl {
    return DeepLinkService.instance.buildAppLink(
      type: widget.contentType,
      id: widget.contentId,
    );
  }

  Uri get _appSchemeUri {
    return DeepLinkService.instance.buildDeepLink(
      type: widget.contentType,
      id: widget.contentId,
    );
  }

  Future<void> _openStoreLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openAppDirectly() async {
    final schemeUri = _appSchemeUri;
    try {
      if (await canLaunchUrl(schemeUri)) {
        await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback to platform store if native app open fails
    if (_isIOS) {
      await _openStoreLink(AppConstant.appStoreLink);
    } else {
      await _openStoreLink(AppConstant.playStoreLink);
    }
  }

  void _continueOnWeb() {
    if (_content == null) return;

    if (widget.contentType == DeepLinkContentType.series) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SeriesDetailsPage(
            seriesId: widget.contentId,
            content: _content!,
          ),
        ),
      );
    } else if (widget.contentType == DeepLinkContentType.short ||
        widget.contentType == DeepLinkContentType.miniSeries) {
      if (_shortDetail != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShortsPlayerPage(short: _shortDetail!),
          ),
        );
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MovieDetailsPage(
            movieId: widget.contentId,
            contentType: widget.contentType == DeepLinkContentType.shortFilm
                ? 'SHORT_FILM'
                : 'MOVIE',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final isDesktop = !ResponsiveWidget.isMobile(context);
    final universalUrlStr = _universalUrl.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141B),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Image.asset(
              ImageConstant.webFullScreenLogo,
              height: 32,
              errorBuilder: (_, __, ___) => const Text(
                'FILMYTELL',
                style: TextStyle(
                  color: Color(0xFFD80D18),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
            icon: const Icon(Icons.home_rounded, color: Colors.white70, size: 18),
            label: const Text(
              'Home',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFD80D18),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading content details...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : _errorMessage != null || _content == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.movie_filter_outlined,
                          size: 64,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Content Not Available',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The requested movie or series could not be found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD80D18),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (_) => false);
                          },
                          icon: const Icon(Icons.home),
                          label: const Text('Go to Home'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroSection(isDesktop, universalUrlStr, theme),
                      const SizedBox(height: 40),
                      _buildDownloadAppSection(isDesktop, theme),
                      const SizedBox(height: 40),
                      _buildFooter(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroSection(
    bool isDesktop,
    String universalUrlStr,
    ThemeData theme,
  ) {
    final content = _content!;
    final title = content.title ?? 'Watch on Filmytell';
    final description = content.description ??
        'Stream exclusive movies, web series, and mini series on Filmytell.';
    final posterUrl = (content.posterUrlList != null &&
            content.posterUrlList!.isNotEmpty)
        ? content.posterUrlList!.first
        : '';
    final backdropUrl = (content.posterUrlList != null &&
            content.posterUrlList!.length > 1)
        ? content.posterUrlList![1]
        : posterUrl;
    final typeLabel = ContentType.displayLabel(
      content.type ?? widget.contentType.name,
    );

    return Stack(
      children: [
        // Backdrop image
        if (backdropUrl.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.22,
              child: Image.network(
                backdropUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x990D0D11),
                  Color(0xFF0D0D11),
                ],
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48.0 : 20.0,
            vertical: 32.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPosterWidget(posterUrl, 260, 390),
                        const SizedBox(width: 36),
                        Expanded(
                          child: _buildDetailsColumn(
                            title,
                            typeLabel,
                            description,
                            universalUrlStr,
                            theme,
                            showQrCode: true,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildPosterWidget(posterUrl, 200, 300),
                        const SizedBox(height: 24),
                        _buildDetailsColumn(
                          title,
                          typeLabel,
                          description,
                          universalUrlStr,
                          theme,
                          showQrCode: false,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosterWidget(String posterUrl, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: posterUrl.isNotEmpty
          ? Image.network(
              posterUrl,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.movie,
                  size: 64,
                  color: Colors.white24,
                ),
              ),
            )
          : const Center(
              child: Icon(
                Icons.movie,
                size: 64,
                color: Colors.white24,
              ),
            ),
    );
  }

  Widget _buildDetailsColumn(
    String title,
    String typeLabel,
    String description,
    String universalUrlStr,
    ThemeData theme, {
    required bool showQrCode,
  }) {
    final content = _content!;
    final language = (content.languageList != null && content.languageList!.isNotEmpty)
        ? (content.languageList!.first.language ?? '')
        : '';
    final releaseDate = content.releaseDate?.toString() ?? '';
    final rating = content.ageRating ?? '';

    return Column(
      crossAxisAlignment: showQrCode
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        // Type Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD80D18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            typeLabel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Title
        Text(
          title,
          textAlign: showQrCode ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),

        // Metadata badges
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: showQrCode ? WrapAlignment.start : WrapAlignment.center,
          children: [
            if (language.isNotEmpty)
              _buildMetaTag(Icons.language, language),
            if (releaseDate.isNotEmpty)
              _buildMetaTag(Icons.calendar_today, releaseDate),
            if (rating.isNotEmpty)
              _buildMetaTag(Icons.verified_user_outlined, rating),
          ],
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          description,
          textAlign: showQrCode ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB0B0C0),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Smart CTA Buttons
        _buildSmartPlatformCtas(theme),
        const SizedBox(height: 20),

        // QR Code Widget on Desktop
        if (showQrCode) ...[
          const Divider(color: Colors.white12, height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: universalUrlStr,
                  size: 96,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan to Watch on Mobile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Open your phone camera to scan and open directly in Filmytell.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: universalUrlStr),
                        );
                        if (!mounted) return;
                        CustomToast.show(
                          context,
                          'Link copied to clipboard',
                          isSuccess: true,
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Color(0xFFD80D18),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Copy Universal Link',
                            style: TextStyle(
                              color: Color(0xFFD80D18),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartPlatformCtas(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Primary Android Download Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD80D18),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          onPressed: () => _openStoreLink(AppConstant.playStoreLink),
          icon: const Icon(LucideIcons.play, size: 18),
          label: const Text(
            'Download for Android',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),

        // Primary iOS Download Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E28),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          onPressed: () => _openStoreLink(AppConstant.appStoreLink),
          icon: const Icon(LucideIcons.apple, size: 18),
          label: const Text(
            'Download for iOS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),

        // Already have app option
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _openAppDirectly,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text(
            'Already have app? Open',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),

        // Continue on Web Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD80D18),
            side: const BorderSide(color: Color(0xFFD80D18)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _continueOnWeb,
          icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
          label: const Text(
            'Continue on Web',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadAppSection(bool isDesktop, ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const Text(
                'Install Filmytell App for Best Experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enjoy 4K Ultra HD streaming, offline downloads, multi-device sync, and zero ad interruptions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildStoreBadgeButton(
                    icon: LucideIcons.play,
                    title: 'GET IT ON',
                    subtitle: 'Google Play',
                    onTap: () => _openStoreLink(AppConstant.playStoreLink),
                  ),
                  _buildStoreBadgeButton(
                    icon: LucideIcons.apple,
                    title: 'Download on the',
                    subtitle: 'App Store',
                    onTap: () => _openStoreLink(AppConstant.appStoreLink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreBadgeButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const Text(
            '© 2026 Filmytell. All rights reserved.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              _buildFooterLink('Privacy Policy', AppConstant.privacyPolicy),
              _buildFooterLink('Terms of Use', AppConstant.termsAndCondition),
              _buildFooterLink('Help Center', '${AppConstant.webAppLink}/help-center.html'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String label, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
