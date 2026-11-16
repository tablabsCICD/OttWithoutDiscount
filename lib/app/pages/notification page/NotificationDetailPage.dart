import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/data/models/response/push_notification_response.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({
    super.key,
    required this.notification,
  });

  final PushNotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: true).getTheme;
    final hasAttachments = notification.attachments.isNotEmpty;
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(
        automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
        title: lang.notification,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _header(context, theme),
          const SizedBox(height: 16),
          _messageCard(theme, lang),
          const SizedBox(height: 16),
          _detailsSection(theme, lang),
          if (hasAttachments) ...[
            const SizedBox(height: 18),
            _attachmentsSection(context, theme),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ThemeData theme) {
    final status = notification.deliveryStatus ?? 'UNKNOWN';
    final priority = notification.priority ?? 'NORMAL';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primaryColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _statusIcon(status),
                  color: theme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: theme.canvasColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (_clean(notification.displayDate) != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 15,
                            color: theme.canvasColor.withOpacity(0.62),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notification.displayDate!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.canvasColor.withOpacity(0.68),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _messageCard(ThemeData theme, AppLocalizations lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(theme, lang.message, Icons.chat_bubble_outline_rounded),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            notification.body,
            style: TextStyle(
              color: theme.canvasColor.withOpacity(0.86),
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailsSection(ThemeData theme, AppLocalizations lang) {
    final rows = <_InfoItem>[
      _InfoItem(
          lang.notifSubject, notification.emailSubject, Icons.subject_outlined),
      _InfoItem(lang.notifSentBy, notification.sentBy, Icons.person_outline),
      _InfoItem(
          lang.notifSentDate, notification.sentDateTime, Icons.send_outlined),
    ].where((item) => _clean(item.value?.toString()) != null).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(theme, lang.notifDetails, Icons.info_outline_rounded),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _infoRow(theme, rows[i]),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    color: theme.canvasColor.withOpacity(0.08),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _attachmentsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          AppLocalizations.of(context)!.notifAttachments,
          Icons.attach_file_rounded,
          count: notification.attachments.length,
        ),
        const SizedBox(height: 10),
        ...notification.attachments.map(
          (attachment) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _attachmentTile(context, theme, attachment),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    ThemeData theme,
    String title,
    IconData icon, {
    int? count,
  }) {
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          count == null ? title : '$title ($count)',
          style: TextStyle(
            color: theme.canvasColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _chip(ThemeData theme, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: theme.canvasColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, _InfoItem item) {
    final value = item.value?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: theme.primaryColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: theme.canvasColor.withOpacity(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentTile(
    BuildContext context,
    ThemeData theme,
    PushNotificationAttachment attachment,
  ) {
    final fileName = _clean(attachment.fileName) ??
        AppLocalizations.of(context)!.notifAttachment;
    final fileUrl = _clean(attachment.fileUrl);
    final fileType = _clean(attachment.fileType);
    final fileSize = _formatFileSize(attachment.fileSize);
    final image = _isImageAttachment(attachment) && fileUrl != null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openAttachment(context, fileUrl),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.canvasColor.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: image
                  ? Image.network(
                      fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _attachmentIconBox(
                        theme,
                        attachment,
                      ),
                    )
                  : _attachmentIconBox(theme, attachment),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (fileType != null) fileType,
                      if (fileSize != null) fileSize,
                    ].join(' - '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.canvasColor.withOpacity(0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (fileUrl != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      Uri.tryParse(fileUrl)?.host ?? fileUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              color: theme.canvasColor.withOpacity(0.62),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentIconBox(
    ThemeData theme,
    PushNotificationAttachment attachment,
  ) {
    return Center(
      child: Icon(
        _attachmentIcon(attachment),
        color: theme.primaryColor,
        size: 24,
      ),
    );
  }

  IconData _statusIcon(String status) {
    final normalized = status.toUpperCase();
    if (normalized.contains('SUCCESS') || normalized.contains('SENT')) {
      return Icons.check_circle_outline_rounded;
    }
    if (normalized.contains('FAIL')) return Icons.error_outline_rounded;
    if (normalized.contains('PENDING')) return Icons.schedule_rounded;
    return Icons.notifications_none_rounded;
  }

  IconData _attachmentIcon(PushNotificationAttachment attachment) {
    final type = attachment.fileType?.toLowerCase() ?? '';
    final name = attachment.fileName?.toLowerCase() ?? '';
    if (_isImageAttachment(attachment)) return Icons.image_outlined;
    if (type.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (type.contains('video')) return Icons.movie_creation_outlined;
    if (type.contains('audio')) return Icons.audio_file_outlined;
    return Icons.insert_drive_file_outlined;
  }

  bool _isImageAttachment(PushNotificationAttachment attachment) {
    final type = attachment.fileType?.toLowerCase() ?? '';
    final name = attachment.fileName?.toLowerCase() ?? '';
    return type.contains('image') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp');
  }

  String? _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _openAttachment(BuildContext context, String? url) async {
    final text = url?.trim();
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.notifAttachmentUrlUnavailable),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(text);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.notifUnableToOpenAttachment),
        ),
      );
    }
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value, this.icon);

  final String label;
  final Object? value;
  final IconData icon;
}
