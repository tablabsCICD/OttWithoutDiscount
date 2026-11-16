import 'package:flutter/foundation.dart';
import 'package:ott/app/core/payment/payment_result_message.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/pages/wallet%20page/PaymentPage.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../provider/themeProvider.dart';
import '../../widgets/show_toast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class SeriesBillingPage extends StatefulWidget {
  final int seriesId;
  final int? seasonId;
  final int? episodeId;
  final double amount;
  final bool isSeason;
  final String? seriesTitle;
  final String? itemTitle;
  final String? rentalDuration;

  const SeriesBillingPage({
    super.key,
    required this.seriesId,
    required this.amount,
    required this.isSeason,
    this.seriesTitle,
    this.itemTitle,
    this.rentalDuration,
    this.seasonId,
    this.episodeId,
  });

  @override
  State<SeriesBillingPage> createState() => _SeriesBillingPageState();
}

class _SeriesBillingPageState extends State<SeriesBillingPage> {
  static const double _minimumRechargeAmount = 100;
  static const double _maximumRechargeAmount = 100000;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      await wallet.getBalance();
      await wallet.getTransactionHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final lang = AppLocalizations.of(context)!;
    final horizontal = ResponsiveWidget.isDesktop(context)
        ? 200.0
        : ResponsiveWidget.isTablet(context)
            ? 80.0
            : 16.0;
    final totalCoins = widget.amount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // -------- Wallet Header --------
          SliverAppBar(
            toolbarHeight: FilmytellAppBarMetrics.compact,
            automaticallyImplyLeading:
                !(kIsWeb || ResponsiveWidget.isTv(context)),
            pinned: true,
            expandedHeight: 230,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Center(
                child: Container(
                  width: ResponsiveWidget.isMobile(context)
                      ? double.infinity
                      : 500,
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
                  child: Consumer<WalletProvider>(
                    builder: (_, walletProvider, __) {
                      return Column(
                        children: [
                          const Spacer(),
                          const Icon(
                            Icons.account_balance_wallet,
                            size: 80,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "₹ ${walletProvider.walletBalance.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            lang.availableBalance,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // -------- Payment Card --------
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
            sliver: SliverToBoxAdapter(
              child: Consumer<WalletProvider>(
                builder: (_, provider, __) {
                  final hasBalance = provider.walletBalance >= totalCoins;

                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isSeason
                                ? lang.billingSeasonPurchase
                                : lang.billingEpisodePurchase,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lang.billingAmountRupees(
                                totalCoins.toStringAsFixed(0)),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Wallet Status
                          Card(
                            color: hasBalance
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang.billingWalletAmount(provider
                                          .walletBalance
                                          .toStringAsFixed(2)),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: hasBalance
                                            ? Colors.green
                                            : theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          hasBalance
                              ? ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.check,
                                      color: Colors.white),
                                  label: Text(
                                    lang.billingProceedToPay,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    _showConfirmationDialog(
                                      context,
                                    );
                                  },
                                )
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.white),
                                  label: Text(
                                    lang.rechargeWallet,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _showRechargeDialog(context),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    final pageContext = context;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer<SeriesProvider>(
              builder: (_, provider, __) {
                final isBusy = isProcessing || provider.isPurchasing;
                final lang = AppLocalizations.of(context)!;

                return AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(lang.billingConfirmPurchase),
                  content: SizedBox(
                    width: ResponsiveWidget.isTabletOrTv(dialogContext)
                        ? 460
                        : null,
                    child: Text(lang.billingConfirmPurchaseQuestion),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isBusy ? null : () => Navigator.pop(dialogContext),
                      child: Text(lang.cancel),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor),
                      onPressed: isBusy
                          ? null
                          : () async {
                              setState(() => isProcessing = true);

                              SeriesPurchaseResult result;
                              if (widget.isSeason) {
                                result = await provider.purchaseSeason(
                                  widget.seasonId!,
                                  widget.seriesId,
                                );
                              } else {
                                result = await provider.purchaseEpisode(
                                  widget.episodeId!,
                                  widget.seriesId,
                                );
                              }

                              if (!mounted) return;
                              Navigator.pop(dialogContext);

                              if (result.success) {
                                /*  await _handlePostPurchaseInvoice(
                                  pageContext,
                                  result,
                                ); */
                                if (!mounted) return;
                                Navigator.pop(pageContext, true);
                              } else {
                                final msg = result.message.isNotEmpty
                                    ? result.message
                                    : (provider.error ??
                                        lang.billingPurchaseFailedTryAgain);
                                CustomToast.show(pageContext, msg,
                                    isSuccess: false);
                              }
                            },
                      child: Text(
                        isBusy ? lang.payProcessing : lang.billingConfirmAndPay,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRechargeDialog(BuildContext context) {
    final pageContext = context;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer<WalletProvider>(
              builder: (_, walletProvider, __) {
                final isBusy = isProcessing || walletProvider.isAddingBalance;
                final lang = AppLocalizations.of(context)!;

                return AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(lang.rechargeWallet),
                  content: SizedBox(
                    width: ResponsiveWidget.isTabletOrTv(dialogContext)
                        ? 460
                        : null,
                    child: TextField(
                      controller: walletProvider.amountController,
                      autofocus: ResponsiveWidget.isTabletOrTv(dialogContext),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).nextFocus(),
                      decoration: InputDecoration(
                        labelText: lang.walletEnterAmount,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isBusy ? null : () => Navigator.pop(dialogContext),
                      child: Text(lang.cancel),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor),
                      onPressed: isBusy
                          ? null
                          : () async {
                              final amount = double.tryParse(
                                      walletProvider.amountController.text) ??
                                  0;

                              if (amount <= 0) {
                                CustomToast.show(
                                  pageContext,
                                  lang.walletEnterValidAmount,
                                  isSuccess: false,
                                );
                                return;
                              }
                              if (amount < _minimumRechargeAmount) {
                                CustomToast.show(
                                  pageContext,
                                  lang.walletMinimumRechargeAmountRs(
                                      _minimumRechargeAmount
                                          .toStringAsFixed(0)),
                                  isSuccess: false,
                                );
                                return;
                              }
                              if (amount > _maximumRechargeAmount) {
                                CustomToast.show(
                                  pageContext,
                                  lang.walletMaximumRechargeAmountRs(
                                      _maximumRechargeAmount
                                          .toStringAsFixed(0)),
                                  isSuccess: false,
                                );
                                return;
                              }

                              setState(() => isProcessing = true);
                              Navigator.pop(dialogContext);

                              final result = await Navigator.push(
                                pageContext,
                                MaterialPageRoute(
                                  builder: (_) => PaymentPage(amount: amount),
                                ),
                              );

                              if (!mounted) return;
                              if (result is Map && result['success'] == true) {
                                _showWalletReflectLoader(pageContext);
                                final addResult = await walletProvider
                                    .onPaymentVerified(
                                  expectedAmount: amount,
                                )
                                    .whenComplete(() {
                                  if (mounted) {
                                    Navigator.of(pageContext,
                                            rootNavigator: true)
                                        .pop();
                                  }
                                });

                                if (!mounted) return;
                                final msg = addResult['message']?.toString() ??
                                    lang.rechargeFailedTryAgain;
                                CustomToast.show(
                                  pageContext,
                                  msg,
                                  isSuccess: addResult['success'] == true,
                                );
                              } else {
                                CustomToast.show(
                                  pageContext,
                                  paymentFailureMessage(
                                    pageContext,
                                    result,
                                    fallback: lang.paymentFailedTryAgain,
                                  ),
                                  isSuccess: false,
                                );
                              }
                            },
                      child: Text(
                        isBusy ? lang.payProcessing : lang.billingProceedToPay,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showWalletReflectLoader(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Text(
                    AppLocalizations.of(dialogContext)!.walletUpdatingBalance)),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePostPurchaseInvoice(
    BuildContext pageContext,
    SeriesPurchaseResult result,
  ) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final lang = AppLocalizations.of(sheetContext)!;
        final invoiceUrl = result.invoiceUrl?.trim() ?? '';
        final hasInvoiceUrl = invoiceUrl.isNotEmpty;
        final purchasedItem = widget.itemTitle ??
            (widget.isSeason
                    ? lang.billingSeasonNumber('${result.seasonId ?? ''}')
                    : lang.billingEpisodeNumber('${result.episodeId ?? ''}'))
                .trim();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.green.shade100,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.billingPurchaseSuccessful,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              result.message,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInvoiceRow(
                          lang.seriesLabel,
                          widget.seriesTitle ?? lang.seriesLabel,
                        ),
                        _buildInvoiceRow(
                          lang.billingItem,
                          purchasedItem.isEmpty
                              ? (widget.isSeason
                                  ? lang.billingSeasonPurchase
                                  : lang.billingEpisodePurchase)
                              : purchasedItem,
                        ),
                        _buildInvoiceRow(
                          lang.billingCoinsDeducted,
                          '${result.coinsDeducted ?? widget.amount.toInt()}',
                        ),
                        _buildInvoiceRow(
                          lang.billingNewBalance,
                          '${result.newBalance ?? lang.searchNotAvailable}',
                        ),
                        _buildInvoiceRow(
                          lang.billingInvoice,
                          hasInvoiceUrl
                              ? lang.billingAvailable
                              : lang.billingNotAvailable,
                          isLast: !hasInvoiceUrl,
                        ),
                        if (hasInvoiceUrl)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ElevatedButton(
                              onPressed: () async {
                                final Uri url = Uri.parse(invoiceUrl);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(lang.viewInvoice),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (hasInvoiceUrl)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          await SharePlus.instance.share(
                            ShareParams(
                              title: lang.purchaseInvoice,
                              subject: lang.purchaseInvoice,
                              text:
                                  '${lang.invoiceShareText(widget.seriesTitle ?? lang.seriesLabel)}\n$invoiceUrl',
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.share_outlined,
                          color: Colors.white,
                        ),
                        label: Text(
                          lang.shareInvoice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (hasInvoiceUrl) const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(lang.done),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceRow(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
