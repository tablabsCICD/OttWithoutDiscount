import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/provider/giftProvider.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
// avoid conflict
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class GiftDetailsPage extends StatefulWidget {
  final int giftMasterId;

  const GiftDetailsPage({super.key, required this.giftMasterId});

  @override
  State<GiftDetailsPage> createState() => _GiftDetailsPageState();
}

class _GiftDetailsPageState extends State<GiftDetailsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<GiftProvider>().getByMasterId(widget.giftMasterId);
    });
  }

  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    CustomToast.show(
        context, AppLocalizations.of(context)!.giftCopiedText(text),
        isSuccess: true);
  }

  Future<void> shareGiftLink(
    String couponCode,
    String movieTitle,
  ) async {
    final giftLink = DeepLinkService.instance.buildGiftDeepLink(couponCode);
    final fallbackLink = DeepLinkService.instance.buildGiftAppLink(couponCode);
    final lang = AppLocalizations.of(context)!;
    final message = lang.giftShareMessage(
      movieTitle,
      giftLink.toString(),
      fallbackLink.toString(),
      couponCode,
    );

    await SharePlus.instance.share(
      ShareParams(
        text: message.trim(),
        subject: lang.giftShareSubject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(
        automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
        title: lang.giftDetails,
      ),
      body: Consumer<GiftProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }

          final giftMaster = provider.giftMaster;
          if (giftMaster == null) {
            return Center(
              child: Text(
                lang.giftNoDetailsFound,
                style: TextStyle(
                  color: theme.canvasColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          final total = giftMaster.totalGiftCount ?? 0;
          final remaining = giftMaster.remainingGiftCount ?? 0;
          final used = total - remaining;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🎬 Movie Info
                if (giftMaster.movie != null)
                  Card(
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (giftMaster.movie?.posterUrlList != null &&
                              giftMaster.movie!.posterUrlList!.isNotEmpty)
                            SizedBox(
                              width: 80,
                              height: 120,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  giftMaster.movie!.posterUrlList!.first,
                                  width: 80,
                                  height: 120,
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
                                  giftMaster.movie?.title ?? "",
                                  style: TextStyle(
                                    color: theme.canvasColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang.giftPriceRupees(
                                      '${giftMaster.movie?.price ?? 0}'),
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang.giftDescriptionValue(
                                      giftMaster.movie?.description ?? "-"),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.canvasColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                /// 🎁 Gift Information
                Card(
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (giftMaster.couponCode != null)
                              GestureDetector(
                                onTap: () {
                                  shareGiftLink(
                                    giftMaster.couponCode!,
                                    giftMaster.movie?.title ??
                                        lang.giftThisMovie,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        giftMaster.couponCode!,
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.share, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (giftMaster.createdDate != null)
                          _buildInfoRow(
                            lang.giftCreatedDate,
                            DateFormat("dd MMM yyyy").format(
                              DateTime.fromMillisecondsSinceEpoch(
                                  giftMaster.createdDate!),
                            ),
                          ),
                        _buildInfoRow(lang.giftTotalGiftCount, "$total"),
                        _buildInfoRow(lang.giftRemaining, "$remaining"),
                        _buildInfoRow(lang.giftUsed, "$used"),
                        _buildInfoRow(lang.giftTotalPaid,
                            "₹${giftMaster.totalPaid ?? 0}"),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// 👥 Users who claimed
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.giftUsersWhoClaimed,
                      style: TextStyle(
                        color: theme.canvasColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$used / $total",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (giftMaster.user == null || giftMaster.user!.isEmpty)
                  Center(
                      child: Column(
                    children: [
                      SizedBox(
                        height: 50,
                      ),
                      Text(lang.giftNoUsersClaimedYet),
                    ],
                  )),
                if (giftMaster.user != null && giftMaster.user!.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: giftMaster.user!.length,
                    itemBuilder: (context, index) {
                      final user = giftMaster.user![index];
                      return Card(
                        color: theme.cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.canvasColor.withOpacity(0.3),
                            backgroundImage:
                                (user.image != null && user.image!.isNotEmpty)
                                    ? NetworkImage(user.image!)
                                    : null,
                            child: (user.image == null || user.image!.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    color: theme.canvasColor.withOpacity(0.7),
                                  )
                                : null,
                          ),
                          title: Text(user.name ?? lang.deviceUnknown),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (user.email != null && user.email!.isNotEmpty)
                                Text(user.email!),
                              if (user.mobile != null &&
                                  user.mobile!.isNotEmpty)
                                Text(user.mobile!),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(flex: 5, child: Text(value ?? "-")),
        ],
      ),
    );
  }
}
