// ignore: file_names
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ott/app/core/services/invoice_service.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/pages/gifted%20movies%20page/GiftedMoviesPage.dart';
import 'package:ott/app/pages/wallet%20page/PaymentPage.dart';
import 'package:ott/app/provider/giftProvider.dart';
import 'package:ott/app/provider/purchaseContentProvider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';
import '../../provider/themeProvider.dart';
import '../../provider/dashboardProvider.dart';
import '../../widgets/show_toast.dart';

class MovieBillingPage extends StatefulWidget {
  final Content movie;
  int giftCount;

  MovieBillingPage({
    super.key,
    required this.movie,
    this.giftCount = 0,
  });

  @override
  State<MovieBillingPage> createState() => _MovieBillingPageState();
}

class _MovieBillingPageState extends State<MovieBillingPage> {
  double moviePrice = 0.0;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _purchaseLoaderVisible = false;

  static const double _minimumRechargeAmount = 100;
  static const double _maximumRechargeAmount = 100000;

  String get _contentLabel {
    final type = (widget.movie.type ?? '').trim().toLowerCase();
    return type == 'series' ? 'series' : 'movie';
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      await walletProvider.getBalance();
      await walletProvider.getTransactionHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final horizontal = ResponsiveWidget.isDesktop(context)
        ? 200.0
        : ResponsiveWidget.isTablet(context)
            ? 80.0
            : 16.0;

    moviePrice = double.tryParse(widget.movie.price.toString()) ?? 0.0;
    final totalCoins =
        moviePrice * (widget.giftCount == 0 ? 1 : widget.giftCount);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          /// -------- Extended Curved Header --------
          SliverAppBar(
            automaticallyImplyLeading:
                !(kIsWeb || ResponsiveWidget.isTv(context)),
            pinned: true,
            expandedHeight: 230,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
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
                          Icon(
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
                          const Text(
                            "Available Balance",
                            style: TextStyle(color: Colors.white70),
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

          /// -------- Payment Card --------
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 8),
            sliver: SliverToBoxAdapter(
              child: Consumer<WalletProvider>(
                builder: (_, provider, __) {
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.movie.title ?? "",
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          widget.giftCount == 0
                              ? Text(
                                  "Price: ₹ ${moviePrice.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 16),
                                )
                              : Text(
                                  "₹ ${moviePrice.toStringAsFixed(0)} × ${widget.giftCount} Gifts",
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                          const SizedBox(height: 6),
                          Text(
                            "Total: ₹ ${totalCoins.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          /// Wallet Status
                          Card(
                            color: provider.walletBalance >= totalCoins
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Image.asset(ImageConstant.coin, width: 22),
                                  //const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Wallet: ₹ ${provider.walletBalance.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            provider.walletBalance >= totalCoins
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

                          provider.walletBalance >= totalCoins
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
                                  label: const Text(
                                    "Proceed to Pay",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    _showConfirmationDialog(
                                      provider,
                                      totalCoins,
                                      widget.movie.id!,
                                      widget.giftCount,
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
                                  label: const Text(
                                    "Recharge Wallet",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => _showRechargeDialog(context),
                                ),

                          const SizedBox(height: 10),

                          /// Gift Card Link
                          Center(
                            child: InkWell(
                              onTap: _showGiftDialog,
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(color: theme.canvasColor),
                                  children: [
                                    const TextSpan(text: 'Have a '),
                                    TextSpan(
                                      text: widget.movie.title ?? "",
                                      style:
                                          TextStyle(color: theme.primaryColor),
                                    ),
                                    const TextSpan(text: ' Gift Card?')
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          /// -------- History --------
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
            sliver: SliverToBoxAdapter(child: _buildTransactionSection()),
          ),
        ],
      ),
    );
  }

  // ---------------- History ----------------
  Widget _buildTransactionSection() {
    return Consumer2<WalletProvider, ThemeProvider>(
      builder: (context, walletProvider, themeProvider, _) {
        final transactions = walletProvider.filteredTransactionHistory;
        final theme = themeProvider.getTheme;

        return Card(
          color: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Transaction History",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: transactions.isEmpty
                        ? const Center(
                            child: Text("No transactions yet",
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) => Divider(
                                color: theme.cardColor.withOpacity(0.2)),
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final isCredit =
                                  tx.action?.toLowerCase() == "credit";
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                  tx.date ?? 0);

                              return ListTile(
                                // leading:
                                //     Image.asset(ImageConstant.coin, width: 22),
                                title: Text(tx.status ?? "NA",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    "${tx.reason ?? ''}\n${DateFormat('dd MMM yyyy • hh:mm a').format(date)}"),
                                isThreeLine: true,
                                trailing: Text(
                                  "₹ ${isCredit ? "+" : "-"}${tx.amount?.toStringAsFixed(0) ?? "--"}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isCredit ? Colors.green : Colors.red,
                                  ),
                                ),
                              );
                            },
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

  // ---------------- Gift Dialog ----------------
  void _showGiftDialog() {
    final theme = Theme.of(context);
    final couponCodeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: ResponsiveWidget.isMobile(context) ? double.infinity : 400,
              child: Stack(
                children: [
                  Positioned(
                    top: 1,
                    left: 1,
                    right: 1,
                    bottom: 1,
                    child: Icon(
                      LucideIcons.gift,
                      size: 200,
                      color: theme.canvasColor.withOpacity(0.1),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Enter Gift Card Number"),
                      const SizedBox(height: 6),
                      CustomTextField(
                        backgroundColor: theme.scaffoldBackgroundColor,
                        isDigits: true,
                        controller: couponCodeController,
                        autofocus: ResponsiveWidget.isTabletOrTv(context),
                        textInputAction: TextInputAction.done,
                        hintText: "Enter 16 Digit Number",
                        textInputType: TextInputType.text,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final provider = Provider.of<GiftProvider>(
                                  context,
                                  listen: false);

                              if (couponCodeController.text.trim().length !=
                                  16) {
                                CustomToast.show(
                                  context,
                                  "Coupon code is invalid",
                                  isSuccess: false,
                                );
                                return;
                              }

                              final result = await provider.useGiftByCoupon(
                                  couponCodeController.text.trim());

                              if (result["success"] == true) {
                                CustomToast.show(
                                  context,
                                  "Coupon applied successfully",
                                  isSuccess: true,
                                );
                                Navigator.pop(context, true);
                              } else {
                                CustomToast.show(
                                  context,
                                  "Failed to apply coupon",
                                  isSuccess: false,
                                );
                              }
                            },
                            child: const Text("Redeem"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- Confirmation ----------------
  void _showConfirmationDialog(
    WalletProvider provider,
    double coins,
    int movieID,
    int giftCount,
  ) {
    final pageContext = context;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer3<WalletProvider, GiftProvider,
                PurchaseContentProvider>(
              builder: (_, walletProvider, giftProvider, purchaseProvider, __) {
                final isBusy = isProcessing ||
                    walletProvider.isDeductingBalance ||
                    giftProvider.isSavingGift ||
                    purchaseProvider.isSavingContent;
                return AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text("Confirm Purchase"),
                  content: SizedBox(
                    width: ResponsiveWidget.isTabletOrTv(dialogContext)
                        ? 460
                        : null,
                    child: const Text("Do you want to confirm the purchase?"),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isBusy ? null : () => Navigator.pop(dialogContext),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor),
                      onPressed: isBusy
                          ? null
                          : () async {
                              setState(() => isProcessing = true);
                              Navigator.pop(dialogContext);
                              _showPurchaseLoader(pageContext);

                              try {
                                await provider.getBalance();
                                if (provider.walletBalance < coins) {
                                  throw Exception(
                                    'Insufficient wallet balance. Please recharge your wallet.',
                                  );
                                }

                                if (giftCount > 0) {
                                  final giftResult =
                                      await Provider.of<GiftProvider>(
                                    pageContext,
                                    listen: false,
                                  ).saveUserGift(widget.movie, giftCount);
                                  if (giftResult['success'] != true) {
                                    throw Exception(
                                      giftResult['message']?.toString() ??
                                          'Gift purchase failed.',
                                    );
                                  }
                                } else {
                                  final purchaseResult = await Provider.of<
                                      PurchaseContentProvider>(
                                    pageContext,
                                    listen: false,
                                  ).saveUserContent(widget.movie);
                                  if (purchaseResult['success'] != true) {
                                    throw Exception(
                                      purchaseResult['message']?.toString() ??
                                          'Unable to grant $_contentLabel access.',
                                    );
                                  }
                                }

                                final walletResult =
                                    await provider.deductBalance(
                                  coins,
                                  movieID,
                                );
                                if (walletResult['success'] != true) {
                                  throw Exception(
                                    walletResult['message']?.toString() ??
                                        'Wallet deduction failed.',
                                  );
                                }

                                Provider.of<DashboardProvider>(
                                  pageContext,
                                  listen: false,
                                ).getContentById(widget.movie.id!).catchError((
                                  error,
                                ) {

                                });

                                if (!mounted) return;
                                _hidePurchaseLoader(pageContext);
                                CustomToast.show(
                                  pageContext,
                                  "Payment successful! Enjoy your content 🎬",
                                  isSuccess: true,
                                );

                                /*  await _handlePostPurchaseInvoice(
                                  pageContext,
                                  quantity: giftCount > 0 ? giftCount : 1,
                                ); */

                                if (giftCount > 0) {
                                  Navigator.pushReplacement(
                                    pageContext,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            GiftedMoviesPage()),
                                  );
                                } else {
                                  Navigator.pop(pageContext, true);
                                }
                              } catch (error) {
                                if (!mounted) return;
                                _hidePurchaseLoader(pageContext);
                                CustomToast.show(
                                  pageContext,
                                  _cleanPurchaseScreenError(error),
                                  isSuccess: false,
                                );
                              }
                            },
                      child: Text(
                        isBusy ? "Processing..." : "Confirm & Pay",
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

  void _showPurchaseLoader(BuildContext context) {
    if (_purchaseLoaderVisible) return;
    _purchaseLoaderVisible = true;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) {
        final theme = Theme.of(context);
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              width: 190,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: theme.primaryColor),
                  const SizedBox(height: 14),
                  const Text(
                    'Processing purchase...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() => _purchaseLoaderVisible = false);
  }

  void _hidePurchaseLoader(BuildContext context) {
    if (!_purchaseLoaderVisible) return;
    Navigator.of(context, rootNavigator: true).pop();
    _purchaseLoaderVisible = false;
  }

  String _cleanPurchaseScreenError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('transactionrequiredexception') ||
        normalized.contains('no entitymanager with actual transaction') ||
        normalized.contains("cannot reliably process 'remove' call") ||
        normalized.contains('nested exception is javax.persistence')) {
      return 'Purchase could not be completed. Please try again in a moment.';
    }
    return message.isEmpty ? 'Purchase failed. Please try again.' : message;
  }

  // ---------------- Recharge ----------------
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
              builder: (_, provider, __) {
                final isBusy = isProcessing || provider.isAddingBalance;

                return AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text("Recharge Wallet"),
                  content: SizedBox(
                    width: ResponsiveWidget.isTabletOrTv(dialogContext)
                        ? 460
                        : null,
                    child: TextField(
                      controller: provider.amountController,
                      autofocus: ResponsiveWidget.isTabletOrTv(dialogContext),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).nextFocus(),
                      decoration: const InputDecoration(
                        labelText: "Enter amount",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isBusy ? null : () => Navigator.pop(dialogContext),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor),
                      onPressed: isBusy
                          ? null
                          : () async {
                              final amount = double.tryParse(
                                      provider.amountController.text) ??
                                  0;

                              if (amount <= 0) {
                                CustomToast.show(
                                  pageContext,
                                  "Enter a valid amount",
                                  isSuccess: false,
                                );
                                return;
                              }
                              if (amount < _minimumRechargeAmount) {
                                CustomToast.show(
                                  pageContext,
                                  "Minimum recharge amount is Rs ${_minimumRechargeAmount.toStringAsFixed(0)}",
                                  isSuccess: false,
                                );
                                return;
                              }
                              if (amount > _maximumRechargeAmount) {
                                CustomToast.show(
                                  pageContext,
                                  "Maximum recharge amount is Rs ${_maximumRechargeAmount.toStringAsFixed(0)}",
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
                                final addResult =
                                    await provider
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
                                    "Recharge failed. Please try again.";
                                CustomToast.show(
                                  pageContext,
                                  msg,
                                  isSuccess: addResult['success'] == true,
                                );
                              } else {
                                CustomToast.show(
                                  pageContext,
                                  result is Map
                                      ? result['message']?.toString() ??
                                          "Payment failed. Please try again."
                                      : "Payment failed. Please try again.",
                                  isSuccess: false,
                                );
                              }
                            },
                      child: Text(
                        isBusy ? "Processing..." : "Proceed to Pay",
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
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(child: Text("Updating wallet balance...")),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePostPurchaseInvoice(
    BuildContext pageContext, {
    required int quantity,
  }) async {
    final user = await LocalSharePreferences.localSharePreferences.getUser();
    if (!mounted || user == null) return;

    try {
      final invoice = await InvoiceService.instance.generatePurchaseInvoice(
        PurchaseInvoiceData(
          user: user,
          contentTitle: widget.movie.title ?? 'Untitled Content',
          contentType: (widget.movie.type ?? 'Movie').toUpperCase(),
          amount: moviePrice,
          purchaseDate: DateTime.now(),
          itemTitle: widget.giftCount > 0 ? 'Gift Purchase' : null,
          itemSubtitle: widget.giftCount > 0
              ? '$quantity recipient${quantity == 1 ? '' : 's'}'
              : null,
          rentalDuration: widget.movie.rentlDuration,
          quantity: quantity,
        ),
      );

      if (!mounted) return;
      await InvoiceService.instance.showShareOptions(pageContext, invoice);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        pageContext,
        'Purchase completed, but invoice generation failed.',
        isSuccess: false,
      );

    }
  }
}
