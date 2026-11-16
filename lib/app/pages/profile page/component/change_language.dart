import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/pages/NavigationPage.dart';
import 'package:ott/app/provider/language_provider.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class ChangeLanguage extends StatefulWidget {
  const ChangeLanguage({super.key});

  @override
  State<ChangeLanguage> createState() => _ChangeLanguageState();
}

class _ChangeLanguageState extends State<ChangeLanguage> {
  bool _saving = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final languageProvider = context.read<LanguageProvider>();
      final userProvider = context.read<UserProvider>();

      // 1️⃣ NEW grouped API
      await languageProvider.fetchGroupedLanguages();

      // 2️⃣ KEEP OLD FLOW (IMPORTANT)
      final userSelected = userProvider.userObject.selectedLanguages ?? [];

      if (userSelected.isNotEmpty) {
        languageProvider.updateLanguages(
          List<String>.from(userSelected),
        );
      }
    });
  }

  Future<void> _saveLanguages(
    UserProvider userProvider,
    LanguageProvider provider,
  ) async {
    if (provider.selectedLanguages.isEmpty) {
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.langSelectAtLeastOne,
        isSuccess: false,
      );
      return;
    }

    setState(() => _saving = true);

    log("=====+====+==== selected languages ${provider.selectedLanguages}");
    final result =
        await userProvider.updateUserLang(provider.selectedLanguages);

    setState(() => _saving = false);

    if (result['success'] == true) {
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.langUpdatedSuccessfully,
        isSuccess: true,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => NavigationPage()),
        (_) => false,
      );
    } else {
      CustomToast.show(
        context,
        "${result['message'] ?? AppLocalizations.of(context)!.langUpdateFailed}",
        isSuccess: false,
      );
    }
  }

  Widget _buildSection(
    String title,
    List items,
    LanguageProvider provider,
    ThemeData theme,
  ) {
    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ResponsiveWidget.isMobile(context)
                ? 2
                : ResponsiveWidget.isTablet(context)
                    ? 4
                    : 5,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            childAspectRatio: 2.5,
          ),
          itemBuilder: (context, index) {
            final lang = items[index];
            final isSelected = provider.selectedLanguages.contains(lang.name);

            return InkWell(
              onTap: () => provider.toggleLanguage(lang.name),
              child: Card(
                color: isSelected ? theme.primaryColor : theme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.native ?? lang.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : theme.canvasColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lang.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white70
                            : theme.canvasColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLanguageTab(
    String title,
    int index,
    ThemeData theme,
  ) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.primaryColor
                  : theme.canvasColor.withOpacity(0.2),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : theme.canvasColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userProvider = context.read<UserProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(title: lang.langPreferredLanguages),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Consumer<LanguageProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return Center(
                  child: CircularProgressIndicator(
                color: theme.primaryColor,
              ));
            }

            if (provider.error != null) {
              return Center(
                child: Text(
                  lang.langFailedToLoad,
                  style: TextStyle(
                    color: theme.canvasColor,
                  ),
                ),
              );
            }

            final languageSections = [
              {
                'title': lang.langMajorIndianLanguages,
                'items': provider.majorIndianLanguages,
              },
              {
                'title': lang.langOtherIndianLanguages,
                'items': provider.otherIndianLanguages,
              },
              {
                'title': lang.langForeignLanguages,
                'items': provider.foreignLanguages,
              },
            ];
            final currentSection = languageSections[_selectedTabIndex];

            return SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildLanguageTab(
                        lang.langMajorIndianLanguages,
                        0,
                        theme,
                      ),
                      _buildLanguageTab(
                        lang.langOtherIndianLanguages,
                        1,
                        theme,
                      ),
                      _buildLanguageTab(
                        lang.langForeignLanguages,
                        2,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _buildSection(
                    currentSection['title'] as String,
                    currentSection['items'] as List,
                    provider,
                    theme,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
      // Save sits in the bottom bar inside a SafeArea so it is always above
      // the system navigation buttons (and never hidden behind them).
      bottomNavigationBar: Consumer<LanguageProvider>(
        builder: (context, provider, _) {
          if (provider.loading || provider.error != null) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () => _saveLanguages(userProvider, provider),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              lang.save,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
