import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ott/app/core/constant/app_constant.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/core/services/session_manager.dart';
import 'package:ott/app/core/utils/image_url_utils.dart';
import 'package:ott/app/pages/profile%20page/component/EditProfilePage.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/app/widgets/edit_address_dialog.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/presentation/web_landing/utils/post_logout_navigation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class AccountDetailsPage extends StatefulWidget {
  const AccountDetailsPage({super.key});

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<UserProvider>();
      await provider.hydrateFromCache();
      final id = provider.userObj.id ?? 0;
      if (id > 0) {
        await provider.getUserById(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(title: lang.accountDetails),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            final user = userProvider.userObj;
            final location = user.location;

            String v(String? value) => (value == null || value.trim().isEmpty)
                ? lang.profileNotAdded
                : value;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileHeader(user, theme),
                      const SizedBox(height: 16),
                      _card(
                        theme: theme,
                        children: [
                          _inputTile(
                              theme, lang.mobileNumber, v(user.mobileNumber),
                              trailing: "EDIT"),
                          const SizedBox(height: 12),
                          _inputTile(
                              theme, lang.profileEmailAddress, v(user.emailId),
                              trailing: "ADD"),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle(theme, lang.profilePersonalDetails),
                      const SizedBox(height: 10),
                      _card(
                        theme: theme,
                        children: [
                          _inputTile(
                            theme,
                            lang.profileName,
                            v([user.firstName, user.lastName]
                                .where((s) => s != null && s.trim().isNotEmpty)
                                .join(' ')),
                          ),
                          const SizedBox(height: 12),
                          _inputTile(theme, lang.profileBirthday, v(user.dob)),
                          /* const SizedBox(height: 12),
                          _chipSelector(theme, "Identity", ["Female", "Male"],
                              selected: _genderLabel(user.gender)), */
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle(theme, lang.profileAddress),
                      const SizedBox(height: 10),
                      _card(
                        theme: theme,
                        children: [
                          /*   _chipSelector(
                              theme, "Save as", ["Home", "Work", "Other"],
                              selected: "Home"),
                          const SizedBox(height: 12), */
                          _inputTile(theme, lang.profileAddressLine,
                              v(location?.officeBuilding)),
                          const SizedBox(height: 12),
                          _inputTile(
                            theme,
                            lang.profileCity,
                            v(location?.city ?? location?.taluka),
                          ),
                          const SizedBox(height: 12),
                          _inputTile(
                              theme, lang.district, v(location?.district)),
                          const SizedBox(height: 12),
                          _inputTile(theme, lang.state, v(location?.state)),
                          const SizedBox(height: 12),
                          _inputTile(theme, lang.country, v(location?.country)),
                          const SizedBox(height: 12),
                          _inputTile(
                              theme, lang.profilePincode, v(location?.pincode)),
                          const SizedBox(height: 12),
                          _editButtons(theme),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle(theme, lang.accountDeletion),
                      const SizedBox(height: 10),
                      _deleteAccountCard(theme, userProvider),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _profileHeader(dynamic user, ThemeData theme) {
    final profilePhotoUrl = normalizeNetworkImageUrl(user.profilePhoto);

    return Center(
      child: Hero(
        tag: "profile",
        child: Stack(
          alignment: Alignment.center,
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
            (user.verified ?? false)
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
    );
  }

  Widget _card({required ThemeData theme, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _editButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            theme,
            icon: Icons.person_outline,
            label: AppLocalizations.of(context)!.editProfile,
            onPressed: _openEditProfile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            theme,
            icon: Icons.location_on_outlined,
            label: AppLocalizations.of(context)!.editAddress,
            onPressed: _showEditAddressDialog,
          ),
        ),
      ],
    );
  }

  Widget _deleteAccountCard(ThemeData theme, UserProvider userProvider) {
    return _card(
      theme: theme,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.profileDeleteAccountInfo,
                style: TextStyle(
                  color: theme.canvasColor.withOpacity(0.74),
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isDeletingAccount ? null : _openDeletionPage,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(AppLocalizations.of(context)!.profileDeletionInfo),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor.withOpacity(0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isDeletingAccount
                    ? null
                    : () => _confirmAndDeleteAccount(userProvider),
                icon: _isDeletingAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_forever, size: 18),
                label: Text(_isDeletingAccount
                    ? AppLocalizations.of(context)!.profileDeleting
                    : AppLocalizations.of(context)!.profileDelete),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openDeletionPage() async {
    final opened = await launchUrl(
      Uri.parse(AppConstant.accountDeletionUrl),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!opened && mounted) {
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileUnableOpenAccountDeletion,
        isSuccess: false,
      );
    }
  }

  Future<void> _confirmAndDeleteAccount(UserProvider userProvider) async {
    final id = userProvider.userObj.id ?? 0;
    if (id <= 0) {
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileAccountNotFound,
        isSuccess: false,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(
              AppLocalizations.of(dialogContext)!.profileDeleteAccountTitle),
          content: Text(
            AppLocalizations.of(dialogContext)!.profileDeleteAccountConfirm,
            style: TextStyle(color: theme.canvasColor.withOpacity(0.78)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                AppLocalizations.of(dialogContext)!.cancel,
                style: TextStyle(color: theme.canvasColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(dialogContext)!.profileDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await userProvider.deleteUser(id);
      await SessionManager.instance.clearLocalSession();
      userProvider.clear();
      userProvider.disposeData();
      if (!mounted) return;
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileAccountDeleted,
        isSuccess: true,
      );
      pushPostLogoutReplacement(context);
    } catch (_) {
      if (!mounted) return;
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.profileUnableDeleteAccount,
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Widget _actionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );

    if (!mounted) return;
    final provider = context.read<UserProvider>();
    final id = provider.userObj.id ?? 0;
    if (id > 0) {
      await provider.getUserById(id);
    }
  }

  Future<void> _showEditAddressDialog() async {
    await showEditAddressDialog(context);
  }

  static Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: theme.canvasColor,
      ),
    );
  }

  Widget _inputTile(ThemeData theme, String label, String value,
      {String? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12, color: theme.canvasColor.withOpacity(0.7)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 14, color: theme.canvasColor),
                ),
              ),
              /* if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                      color: theme.primaryColor, fontWeight: FontWeight.w600),
                ) */
            ],
          ),
        )
      ],
    );
  }

  Widget _chipSelector(ThemeData theme, String title, List<String> options,
      {required String selected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12, color: theme.canvasColor.withOpacity(0.7))),
        const SizedBox(height: 8),
        Row(
          children: options.map((e) {
            final isSelected = e == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.dividerColor.withOpacity(0.5)),
                  color: isSelected
                      ? theme.primaryColor.withOpacity(0.08)
                      : theme.cardColor,
                ),
                child: Text(
                  e,
                  style: TextStyle(
                    color: isSelected ? theme.primaryColor : theme.canvasColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _bottomButton(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        color: theme.scaffoldBackgroundColor,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {},
          child: Text(
            AppLocalizations.of(context)!.profileSaveChanges,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  String _genderLabel(String? gender) {
    final g = (gender ?? '').trim().toLowerCase();
    if (g == 'female' || g == 'woman') return 'Woman';
    if (g == 'male' || g == 'man') return 'Man';
    return '';
  }
}
