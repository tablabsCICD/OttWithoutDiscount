import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/provider/purchase_history_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/content_type_chip.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/response/purchase_history_response.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

/// Filter values sent to the purchase history API (unchanged).
const List<String> _purchaseTypeFilters = <String>[
  'All',
  'Movies',
  'Series',
  'Shorts',
  'Short Films',
];

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key});

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PurchaseHistoryProvider>().fetchPurchaseHistory();
    });
  }

  String _filterLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'All':
        return l10n.all;
      case 'Movies':
        return l10n.movie;
      case 'Series':
        return l10n.series;
      case 'Shorts':
        return l10n.minSeries;
      case 'Short Films':
        return l10n.shortFilms;
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar.main(title: l10n.purchaseHistory),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Consumer<PurchaseHistoryProvider>(
              builder: (context, provider, _) {
                return Column(
                  children: [
                    _buildFilters(context, theme, l10n, provider),
                    Expanded(child: _buildBody(context, theme, l10n, provider)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    PurchaseHistoryProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _purchaseTypeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = _purchaseTypeFilters[index];
                final selected = provider.selectedType == value;
                return ContentTypeChip(
                  label: _filterLabel(l10n, value),
                  selected: selected,
                  onTap: provider.isLoading
                      ? null
                      : () => provider.setSelectedType(value),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: l10n.from,
                  date: provider.selectedFromDate,
                  onTap: () => _pickDate(context, provider, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: l10n.to,
                  date: provider.selectedToDate,
                  onTap: () => _pickDate(context, provider, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    PurchaseHistoryProvider provider,
  ) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.items.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n.failedLoadPurchaseHistory,
        subtitle: provider.error,
        actionLabel: l10n.retry,
        onAction: provider.fetchPurchaseHistory,
      );
    }

    if (provider.items.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.noPurchaseHistory,
        subtitle: l10n.noPurchaseHistoryHint,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.fetchPurchaseHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: provider.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) =>
            _PurchaseHistoryCard(item: provider.items[index]),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    PurchaseHistoryProvider provider,
    bool isFromDate,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isFromDate ? provider.selectedFromDate : provider.selectedToDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final pickedDate = DateUtils.dateOnly(picked);
      final fromDate = DateUtils.dateOnly(provider.selectedFromDate);
      final toDate = DateUtils.dateOnly(provider.selectedToDate);
      final isInvalidRange = isFromDate
          ? !pickedDate.isBefore(toDate)
          : !fromDate.isBefore(pickedDate);

      if (isInvalidRange) {
        if (!context.mounted) return;
        CustomToast.show(
          context,
          l10n.startDateBeforeEndDate,
          isSuccess: false,
        );
        return;
      }

      await provider.setDate(picked, isFromDate);
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: theme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor?.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _safeFormat('dd MMM yyyy', locale, date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: theme.primaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor?.withValues(alpha: 0.65)),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static _StatusStyle of(AppLocalizations l10n, PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.success:
        return _StatusStyle(l10n.statusSuccessful, const Color(0xFF2E7D32),
            Icons.check_circle_rounded);
      case PurchaseStatus.failed:
        return _StatusStyle(
            l10n.statusFailed, const Color(0xFFC62828), Icons.error_rounded);
      case PurchaseStatus.cancelled:
        return _StatusStyle(l10n.statusCancelled, const Color(0xFF6D6D6D),
            Icons.cancel_rounded);
      case PurchaseStatus.pending:
        return _StatusStyle(l10n.statusPending, const Color(0xFFEF6C00),
            Icons.schedule_rounded);
    }
  }
}

class _PurchaseHistoryCard extends StatelessWidget {
  const _PurchaseHistoryCard({required this.item});

  final PurchaseHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final content = item.content;
    final title = content?.title ?? item.itemTitle ?? l10n.purchasedContent;
    final type = item.contentType ?? content?.type;
    final purchaseDate = item.purchaseDate;
    final invoiceUrl = item.invoiceUrl?.trim() ?? '';
    final invoiceRef = item.invoiceNumber ?? item.invoiceId;
    final status = _StatusStyle.of(l10n, item.status);
    final amount = (item.amount ?? content?.price ?? 0).toDouble();
    final mutedText = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    final isCompact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: poster, title, type, date, status.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: isCompact ? 56 : 68,
                    height: isCompact ? 80 : 96,
                    child: ResponsivePosterImage(
                      imageUrls: content?.posterUrlList,
                      fit: BoxFit.cover,
                      enableAmbientBackdrop: false,
                      backgroundColor: theme.dividerColor,
                      fallbackBuilder: () => Container(
                        color: theme.dividerColor,
                        child: Icon(Icons.movie_outlined, color: mutedText),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (type != null && type.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ContentType.localizedLabel(l10n, type),
                          style: TextStyle(fontSize: 12, color: mutedText),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        purchaseDate != null
                            ? _safeFormat(
                                'dd MMM yyyy, hh:mm a', locale, purchaseDate)
                            : '—',
                        style: TextStyle(fontSize: 12, color: mutedText),
                      ),
                      const SizedBox(height: 8),
                      _StatusPill(style: status),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: item.status == PurchaseStatus.success
                            ? theme.textTheme.bodyMedium?.color
                            : mutedText,
                        decoration: item.status == PurchaseStatus.cancelled ||
                                item.status == PurchaseStatus.failed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      l10n.amountPaid,
                      style: TextStyle(fontSize: 11, color: mutedText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _DashedDivider(color: theme.dividerColor),
          // Details: transaction reference, invoice, payment method, duration.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              children: [
                if (item.transactionId != null)
                  _DetailRow(
                    label: l10n.transactionId,
                    value: item.transactionId!,
                    copyable: true,
                  ),
                if (invoiceRef != null)
                  _DetailRow(label: l10n.invoiceNumber, value: invoiceRef),
                if ((item.paymentMethod ?? '').trim().isNotEmpty)
                  _DetailRow(
                    label: l10n.paymentMethod,
                    value: item.paymentMethod!,
                  ),
                if ((item.rentalDuration ?? '').trim().isNotEmpty)
                  _DetailRow(
                    label: l10n.rentDuration,
                    value: item.rentalDuration!,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: invoiceUrl.isNotEmpty
                ? Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _viewInvoice(context, invoiceUrl),
                        icon:
                            const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(l10n.viewInvoice),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _shareInvoice(context, invoiceUrl),
                        icon: const Icon(
                          Icons.share_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          l10n.shareInvoice,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      l10n.invoiceNotAvailable,
                      style: TextStyle(fontSize: 12, color: mutedText),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewInvoice(BuildContext context, String invoiceUrl) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final uri = Uri.tryParse(invoiceUrl);
      if (uri == null) {
        CustomToast.show(context, l10n.invalidInvoiceUrl, isSuccess: false);
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        CustomToast.show(context, l10n.unableOpenInvoice, isSuccess: false);
      }
    } catch (error) {
      if (!context.mounted) return;
      CustomToast.show(context, l10n.unableOpenInvoice, isSuccess: false);
    }
  }

  Future<void> _shareInvoice(BuildContext context, String invoiceUrl) async {
    final l10n = AppLocalizations.of(context)!;
    final title =
        item.content?.title ?? item.itemTitle ?? l10n.purchasedContent;
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: l10n.purchaseInvoice,
          subject: l10n.purchaseInvoice,
          text: '${l10n.invoiceShareText(title)}\n$invoiceUrl',
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      CustomToast.show(context, l10n.unableShareInvoice, isSuccess: false);
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedText = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    final valueText = Text(
      value,
      textAlign: TextAlign.end,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: mutedText)),
          const SizedBox(width: 12),
          Expanded(
            child: copyable
                ? InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      if (!context.mounted) return;
                      CustomToast.show(
                        context,
                        AppLocalizations.of(context)!.copied,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(child: valueText),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_rounded, size: 14, color: mutedText),
                      ],
                    ),
                  )
                : valueText,
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 6.0;
          const gap = 4.0;
          final count =
              (constraints.maxWidth / (dashWidth + gap)).floor().clamp(1, 400);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(decoration: BoxDecoration(color: color)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Formats [date] in the app's locale, falling back to English if intl has
/// no date symbols for that locale.
String _safeFormat(String pattern, String locale, DateTime date) {
  try {
    return DateFormat(pattern, locale).format(date);
  } catch (_) {
    return DateFormat(pattern).format(date);
  }
}
