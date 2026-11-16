import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';
import 'package:ott/app/provider/ticketProvider.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  _HelpSupportPageState createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _supportFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Provider.of<TicketProvider>(context, listen: false)
        .getRaisedTicketByUserId();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar.main(title: lang.helpAndSupport),
      body: Consumer<TicketProvider>(
        builder: (context, provider, child) {
          final maxWidth = ResponsiveWidget.isMobile(context) ? 620.0 : 760.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: CustomScrollView(
                slivers: [
                  /*  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: _buildHeaderCard(theme, lang),
                    ),
                  ), */
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildAppTourCard(theme),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildFormCard(theme, lang, provider),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: _buildTicketsHeader(theme, lang),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final query = provider.ticketList[index];
                        final ticketDate = provider.ticketList[index].date;
                        final formattedDate = ticketDate == null
                            ? lang.helpDateUnavailable
                            : DateFormat('dd MMM yyyy, hh:mm a').format(
                                DateTime.fromMillisecondsSinceEpoch(ticketDate),
                              );

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _buildTicketCard(
                            theme,
                            lang,
                            provider,
                            query.tickedId,
                            query.image,
                            query.topic ?? '',
                            query.feedback ?? '',
                            formattedDate,
                          ),
                        );
                      },
                      childCount: provider.ticketList.length,
                    ),
                  ),
                  if (provider.isLoadingTickets)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    )
                  else if (provider.ticketList.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: _buildEmptyTickets(theme),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, AppLocalizations lang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.92),
            theme.primaryColor.withOpacity(0.65),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.helpAndSupport,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lang.helpResponseTimeInfo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTourCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withOpacity(0.14),
          child: Icon(Icons.tour_rounded, color: theme.primaryColor),
        ),
        title: Text(
          AppLocalizations.of(context)!.profileAppTour,
          style: TextStyle(
            color: theme.canvasColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.helpAppTourSubtitle,
          style: TextStyle(color: theme.canvasColor.withOpacity(0.68)),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: theme.canvasColor.withOpacity(0.7)),
        onTap: () {
          context.read<OnboardingTourProvider>().replayTour(context: context);
        },
      ),
    );
  }

  Widget _buildFormCard(
      ThemeData theme, AppLocalizations lang, TicketProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _supportFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.helpRaiseTicket,
                style: TextStyle(
                  color: theme.canvasColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: provider.topicController,
                hintText: lang.enterYourQuery,
                textInputType: TextInputType.multiline,
                maxLine: 5,
                validator: (value) {
                  final query = value?.trim() ?? '';
                  if (query.isEmpty) {
                    return lang.helpPleaseEnterQuery;
                  }
                  if (query.length < 10) {
                    return lang.helpQueryMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              provider.uploadedImageUrl != null
                  ? Row(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image:
                                  NetworkImage(provider.uploadedImageUrl ?? ""),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.helpAttachmentAdded,
                                style: TextStyle(
                                  color: theme.canvasColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () => provider.clearAttachment(),
                                icon: Icon(Icons.delete,
                                    color: theme.primaryColor),
                                label: Text(
                                  lang.helpRemove,
                                  style: TextStyle(color: theme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: provider.isUploading
                          ? null
                          : () => provider.pickImage(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.primaryColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: provider.isUploading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.primaryColor,
                              ),
                            )
                          : const Icon(Icons.attach_file),
                      label: Text(
                        provider.isUploading
                            ? lang.helpUploading
                            : lang.attachImage,
                      ),
                    ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: provider.isSubmitting || provider.isUploading
                      ? null
                      : () async {
                          if (!(_supportFormKey.currentState?.validate() ??
                              false)) {
                            return;
                          }

                          final confirmed =
                              await _showSubmitConfirmationDialog(theme);
                          if (!mounted || confirmed != true) return;

                          final result = await provider.raiseTicket();
                          if (!mounted) return;

                          CustomToast.show(
                            context,
                            result['message']?.toString() ??
                                lang.authSomethingWentWrong,
                            isSuccess: result['success'] == true,
                          );

                          if (result['success'] == true) {
                            await provider.getRaisedTicketByUserId();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: provider.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(lang.submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showSubmitConfirmationDialog(ThemeData theme) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            AppLocalizations.of(dialogContext)!.helpSubmitRequestTitle,
            style: TextStyle(color: theme.canvasColor),
          ),
          content: Text(
            AppLocalizations.of(dialogContext)!.helpSubmitRequestConfirm,
            style: TextStyle(color: theme.canvasColor),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppLocalizations.of(dialogContext)!.submit),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTicketsHeader(ThemeData theme, AppLocalizations lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          lang.helpYourRequests,
          style: TextStyle(
            color: theme.canvasColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_outlined,
                  size: 16, color: theme.primaryColor),
              const SizedBox(width: 6),
              Text(
                lang.sent,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTickets(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primaryColor.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            color: theme.primaryColor,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.helpNoSentTickets,
            style: TextStyle(
              color: theme.canvasColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.helpNoSentTicketsHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.canvasColor.withOpacity(0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(
    ThemeData theme,
    AppLocalizations lang,
    TicketProvider provider,
    int? ticketId,
    String? imageUrl,
    String topic,
    String feedback,
    String dateText,
  ) {
    final attachmentUrl = imageUrl?.trim() ?? '';

    return Card(
      color: theme.cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            attachmentUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      attachmentUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(Icons.broken_image, color: theme.primaryColor),
                      ),
                    ),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.help_outline, color: theme.primaryColor),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic,
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    feedback,
                    style: TextStyle(
                      color: theme.canvasColor.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        dateText,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: provider.deletingTicketId == ticketId
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor,
                      ),
                    )
                  : Icon(
                      Icons.delete,
                      color: theme.primaryColor,
                      size: 18,
                    ),
              onPressed: ticketId == null || provider.deletingTicketId != null
                  ? null
                  : () async {
                      final shouldDelete = await _showDeleteTicketDialog(theme);
                      if (shouldDelete != true || !context.mounted) return;

                      final result = await provider.deleteTicket(ticketId);
                      if (!context.mounted) return;

                      CustomToast.show(
                        context,
                        result['message']?.toString() ??
                            lang.authSomethingWentWrong,
                        isSuccess: result['success'] == true,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteTicketDialog(ThemeData theme) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            AppLocalizations.of(dialogContext)!.helpDeleteTicketTitle,
            style: TextStyle(
              color: theme.canvasColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppLocalizations.of(dialogContext)!.helpDeleteTicketConfirm,
            style: TextStyle(
              color: theme.canvasColor.withOpacity(0.75),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                AppLocalizations.of(dialogContext)!.cancel,
                style: TextStyle(color: theme.canvasColor),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppLocalizations.of(dialogContext)!.profileDelete),
            ),
          ],
        );
      },
    );
  }
}
