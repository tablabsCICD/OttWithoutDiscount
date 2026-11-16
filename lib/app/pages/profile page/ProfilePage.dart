import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ott/app/core/constant/app_constant.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/core/services/legal_document_service.dart';
import 'package:ott/app/core/services/session_manager.dart';
import 'package:ott/app/core/utils/image_url_utils.dart';
import 'package:ott/app/core/utils/legal_document_url_utils.dart';
import 'package:ott/app/pages/bookmarks%20page/bookmark_page.dart';
import 'package:ott/app/pages/gifted%20movies%20page/GiftedMoviesPage.dart';
import 'package:ott/app/pages/help%20support%20page/HelpSupportPage.dart';
import 'package:ott/app/pages/device%20management%20page/DeviceManagementPage.dart';
import 'package:ott/app/pages/NavigationPage.dart';
import 'package:ott/app/pages/notification%20page/NotificationPage.dart';
import 'package:ott/app/pages/profile%20page/component/EditProfilePage.dart';
import 'package:ott/app/pages/profile%20page/component/account_details_page.dart';
import 'package:ott/app/pages/profile%20page/PurchaseHistoryPage.dart';
import 'package:ott/app/pages/profile%20page/component/about_filmytell_dialog.dart';
import 'package:ott/app/pages/profile%20page/component/change_language.dart';
import 'package:ott/app/pages/upcoming%20movies%20page/UpcomingPage.dart';
import 'package:ott/app/pages/wallet%20page/WalletPage.dart';
import 'package:ott/app/pages/watchlist%20page/WatchlistPage.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/purchase_history_provider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/widgets/LanguageDropdown.dart';
import 'package:ott/app/widgets/gift_claim_dialog.dart';
import 'package:ott/app/widgets/ott_tv_focus.dart';
import 'package:ott/app/widgets/shimmer%20loader/profile_shimmer.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/presentation/web_landing/utils/post_logout_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constant/prefrense_constant.dart';
import '../../core/utils/sharepreferences.dart';
import '../../provider/userProvider.dart';
import '../../widgets/show_toast.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onOpenDetail});

  final void Function(String title, Widget page)? onOpenDetail;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _openDetail(String title, Widget page) {
    final openInShell = widget.onOpenDetail;
    if (openInShell != null) {
      openInShell(title, page);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    });
  }

  Future<void> _fetchUserData() async {
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.hydrateFromCache();
    if (!mounted) return;

    if (user != null) {
      await userProvider.getUserById(user.id ?? 0);
      if (!mounted) return;
    }
    await Provider.of<WalletProvider>(context, listen: false).getBalance();
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final documentUrls =
          await LegalDocumentService.instance.getDocumentUrls();
      final opened = await launchUrl(
        legalDocumentViewUri(documentUrls.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        CustomToast.show(
          context,
          AppLocalizations.of(context)!.profileUnableOpenPrivacyPolicy,
          isSuccess: false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileUnableOpenPrivacyPolicy,
        isSuccess: false,
      );
    }
  }

  Future<void> _openTerms() async {
    try {
      final documentUrls =
          await LegalDocumentService.instance.getDocumentUrls();
      final opened = await launchUrl(
        legalDocumentViewUri(documentUrls.termsAndConditionsUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        CustomToast.show(
          context,
          AppLocalizations.of(context)!.profileUnableOpenTerms,
          isSuccess: false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileUnableOpenTerms,
        isSuccess: false,
      );
    }
  }

  Future<void> _openRateUs() async {
    try {
      bool launched = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final marketUri = Uri.parse('market://details?id=com.filmytell.ott');
        launched = await launchUrl(
          marketUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched) {
        launched = await launchUrl(
          Uri.parse(AppConstant.playStoreLink),
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched && mounted) {
        CustomToast.show(
          context,
          AppLocalizations.of(context)!.profileUnableOpenRating,
          isSuccess: false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileUnableOpenRating,
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var walletProvider = Provider.of<WalletProvider>(context);
    double walletBalance = walletProvider.walletBalance;
    final lang = AppLocalizations.of(context)!;
    var themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    var selectedThemeData = themeProvider.getTheme;

    return Scaffold(
      body: isLoading
          ? ProfileShimmer()
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(context, selectedThemeData),
                SliverToBoxAdapter(
                  child: Consumer<UserProvider>(
                      builder: (context, userProvider, child) {
                    return SingleChildScrollView(
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 5),
                            profileCard(
                              lang.myCredits,
                              [
                                ProfileOption(
                                  icon: Icons.account_balance_wallet,
                                  title: lang.wallet,
                                  balance: walletBalance,
                                  onTap: () =>
                                      _openDetail(lang.wallet, WalletPage()),
                                ),
                              ],
                            ),
                            profileCard(
                              lang.features,
                              [
                                ProfileOption(
                                  icon: Icons.bookmark,
                                  title: lang.profileBookmarks,
                                  onTap: () => _openDetail(
                                      lang.profileBookmarks, BookmarkPage()),
                                ),
                                ProfileOption(
                                  icon: Icons.history,
                                  title: lang.watchlist,
                                  onTap: () => _openDetail(
                                      lang.watchlist, const WatchlistPage()),
                                ),
                                ProfileOption(
                                  icon: Icons.receipt_long,
                                  title: lang.purchaseHistory,
                                  onTap: () => _openDetail(
                                    lang.purchaseHistory,
                                    ChangeNotifierProvider(
                                      create: (_) => PurchaseHistoryProvider(),
                                      child: const PurchaseHistoryPage(),
                                    ),
                                  ),
                                ),
                                ProfileOption(
                                  icon: Icons.download_rounded,
                                  title: lang.downloads,
                                  onTap: () => _openDetail(
                                    lang.downloads,
                                    const WatchlistPage(
                                      initialFilter: WatchlistFilter.downloaded,
                                    ),
                                  ),
                                ),
                                ProfileOption(
                                  icon: Icons.upcoming,
                                  title: lang.upcoming,
                                  onTap: () => _openDetail(
                                      lang.upcoming, UpcomingPage()),
                                ),
                                ProfileOption(
                                  icon: Icons.notifications,
                                  title: lang.notification,
                                  onTap: () => _openDetail(lang.notification,
                                      const NotificationPage()),
                                ),
                                ProfileOption(
                                  icon: Icons.language_sharp,
                                  title: lang.selectPreferredLanguage,
                                  onTap: () {
                                    _openDetail(lang.selectPreferredLanguage,
                                        const ChangeLanguage());
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.manage_accounts_outlined,
                                  title: lang.accountDetails,
                                  onTap: () {
                                    _openDetail(lang.accountDetails,
                                        const AccountDetailsPage());
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.devices_other_outlined,
                                  title: lang.profileRegisteredDevices,
                                  onTap: () {
                                    _openDetail(lang.profileRegisteredDevices,
                                        const DeviceManagementPage());
                                  },
                                ),
                              ],
                            ),
                            profileCard(
                              lang.gifts,
                              [
                                ProfileOption(
                                  icon: Icons.history_sharp,
                                  title: lang.giftedByYou,
                                  onTap: () => _openDetail(
                                      lang.giftedByYou, GiftedMoviesPage()),
                                ),
                                ProfileOption(
                                  icon: LucideIcons.gift,
                                  title: lang.claimGiftCard,
                                  onTap: () {
                                    showGiftClaimDialog(
                                      context,
                                      isFromDeepLink: false,
                                    );
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.card_giftcard_rounded,
                                  title: lang.giftedToYou,
                                  onTap: () => _openDetail(
                                    lang.giftedToYou,
                                    const WatchlistPage.giftedToYou(),
                                  ),
                                ),
                              ],
                            ),
                            profileCard(
                              lang.feedbackAndInformation,
                              [
                                ProfileOption(
                                  icon: Icons.support_agent_sharp,
                                  title: lang.help,
                                  onTap: () => _openDetail(
                                      lang.help, const HelpSupportPage()),
                                ),
                                ProfileOption(
                                  icon: Icons.tour_rounded,
                                  title: lang.profileAppTour,
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => const NavigationPage(
                                          initialIndex: 0,
                                          initialHomeContentType: 'MOVIE',
                                          startAppTourOnHome: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.file_copy,
                                  title: lang.privacyPolicy,
                                  onTap: () {
                                    _openPrivacyPolicy();
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.file_copy,
                                  title: lang.profileTermsCondition,
                                  onTap: () {
                                    _openTerms();
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.info,
                                  title: lang.aboutFilmytell,
                                  onTap: () {
                                    _openDetail(lang.aboutFilmytell,
                                        const AboutFilmytellScreen());
                                  },
                                ),
                                ProfileOption(
                                  icon: Icons.star,
                                  title: lang.rateUs,
                                  onTap: _openRateUs,
                                ),
                              ],
                            ),
                            profileCard(
                              '',
                              [
                                ProfileOption(
                                  icon: Icons.logout,
                                  title: lang.logout,
                                  onTap: () {
                                    _showCupertinoDialog(context);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const _ProfileBrandingFooter(),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
    );
  }

  void _showCupertinoDialog(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(lang.navLogoutConfirm),
        actions: [
          CupertinoDialogAction(
            textStyle: TextStyle(color: theme.canvasColor),
            child: Text(lang.cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            textStyle: TextStyle(color: theme.primaryColor),
            child: Text(lang.logout),
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog

              await SessionManager.instance.logoutFromServer();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isLoggedIn');
              LocalSharePreferences localSharePreferences =
                  LocalSharePreferences();
              await localSharePreferences.clearSession();

              // clear all the APIs used for the user
              Provider.of<DashboardProvider>(context, listen: false).clear();
              Provider.of<BookmarkProvider>(context, listen: false).clear();
              Provider.of<UserProvider>(context, listen: false).clear();
              Provider.of<UserProvider>(context, listen: false).disposeData();
              pushPostLogoutReplacement(context);
            },
          ),
        ],
      ),
    );
  }

  Widget profileCard(String title, List<Widget> children) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: 8.0,
                      bottom: 4,
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: theme.canvasColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                : SizedBox(),
            ...children,
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, ThemeData theme) {
    final lang = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context);
    bool isDark = theme.brightness == Brightness.dark;
    var themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final profilePhotoUrl =
        normalizeNetworkImageUrl(userProvider.userObj.profilePhoto);

    // Show a back arrow when Profile was pushed as its own screen (e.g. from
    // the app bar profile icon). As a bottom-navigation tab there is nothing
    // to go back to, so no arrow is shown there.
    final canGoBack = Navigator.of(context).canPop();
    // On mobile the red header panel spans the full width behind the toolbar,
    // so its icons are white in both themes. On wider screens the panel is a
    // centred card and the toolbar icons sit on the page background.
    final toolbarForeground = ResponsiveWidget.isMobile(context)
        ? Colors.white
        : theme.canvasColor;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      leading: canGoBack
          ? BackButton(
              color: toolbarForeground,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      expandedHeight: 280,
      backgroundColor: theme.scaffoldBackgroundColor,
      centerTitle: ResponsiveWidget.isDesktop(context) ? true : false,
      actions: [
        LanguageDropdown(foregroundColor: toolbarForeground),
        IconButton(
          icon: Icon(
            isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            color: toolbarForeground,
          ),
          tooltip: lang.navToggleTheme,
          onPressed: () {
            themeProvider.toggleTheme();
          },
        ),
        IconButton(
          onPressed: () {
            _showCupertinoDialog(context);
          },
          tooltip: lang.logout,
          icon: Icon(
            Icons.logout,
            color: toolbarForeground,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        //titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),

        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],

        background: Center(
          child: Container(
            width: ResponsiveWidget.isMobile(context) ? double.infinity : 500,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: ResponsiveWidget.isDesktop(context)
                  ? BorderRadius.circular(60)
                  : const BorderRadius.only(
                      bottomLeft: Radius.circular(70),
                      bottomRight: Radius.circular(70),
                    ),
            ),
            child: Column(
              children: [
                Spacer(),
                Hero(
                  tag: "profile",
                  child: Stack(
                    alignment: AlignmentGeometry.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: theme.cardColor,
                        child: ClipOval(
                          child: profilePhotoUrl.isEmpty
                              ? Image.asset(
                                  ImageConstant.profile,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  profilePhotoUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    ImageConstant.profile,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      (userProvider.userObj.verified ?? false)
                          ? Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.scaffoldBackgroundColor,
                                ),
                                child: Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                              ),
                            )
                          : SizedBox(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (() {
                    final first = (userProvider.userObj.firstName ?? '').trim();
                    final last = (userProvider.userObj.lastName ?? '').trim();
                    final full = '$first $last'.trim();
                    return full.isNotEmpty ? full : lang.profileUserFallback;
                  })(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  userProvider.userObj.emailId ?? "",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  userProvider.userObj.mobileNumber ?? '',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _openDetail(lang.editProfile, const EditProfilePage());
                  },
                  child: Text(
                    lang.editProfile,
                    style: TextStyle(
                      color: theme.canvasColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final double? balance;

  const ProfileOption({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.balance,
  });

  @override
  State<ProfileOption> createState() => _ProfileOptionState();
}

class _ProfileOptionState extends State<ProfileOption> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option = SizedBox(
      width: ResponsiveWidget.isMobile(context) ? double.infinity : 600,
      child: ListTile(
        dense: true,
        leading: Icon(widget.icon, color: Theme.of(context).primaryColor),
        title: Text(
          widget.title,
          style: TextStyle(
            color: theme.canvasColor,
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: widget.balance != null
            ? Text(
                '₹ ${widget.balance!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: theme.canvasColor.withOpacity(0.6),
                  fontWeight: FontWeight.normal,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: widget.onTap,
      ),
    );

    if (ResponsiveWidget.isMobile(context)) return option;

    return OttTvFocus(
      onTap: widget.onTap,
      borderRadius: 12,
      scale: 1.025,
      child: option,
    );
  }
}

/// Logo, copyright, app version and technical-partner credit shown below the
/// Logout card. Colours follow the active theme (canvasColor is the app's
/// foreground colour in both Light and Dark themes).
class _ProfileBrandingFooter extends StatefulWidget {
  const _ProfileBrandingFooter();

  @override
  State<_ProfileBrandingFooter> createState() => _ProfileBrandingFooterState();
}

class _ProfileBrandingFooterState extends State<_ProfileBrandingFooter> {
  late final Future<String> _version = _loadVersion();

  static Future<String> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.trim().isNotEmpty) return info.version;
    } catch (_) {}
    return AppConstant.appVersion;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;
    final muted = theme.canvasColor.withValues(alpha: 0.55);
    final subtle = theme.canvasColor.withValues(alpha: 0.42);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.5,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.scaffoldBackgroundColor,
              foregroundImage: AssetImage(ImageConstant.logo),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang.profileCopyright,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 2),
          FutureBuilder<String>(
            future: _version,
            initialData: AppConstant.appVersion,
            builder: (context, snapshot) => Text(
              lang.profileVersion(snapshot.data ?? AppConstant.appVersion),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 48,
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.canvasColor.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lang.profileTechnicalPartner,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtle,
              fontSize: 8,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Tablabs Technologies Pvt. Ltd.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
