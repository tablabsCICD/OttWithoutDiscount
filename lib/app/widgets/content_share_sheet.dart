import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/ShareService.dart';
import 'package:ott/app/pages/movie%20details%20page/component/actionButtonWidget.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/content.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showContentShareSheet(
  BuildContext context,
  Content content, {
  DeepLinkContentType contentType = DeepLinkContentType.movie,
  String unavailableMessage = 'Content details are not available yet',
}) async {
  if (content.id == null || content.id! <= 0) {
    CustomToast.show(
      context,
      unavailableMessage,
      isSuccess: false,
    );
    return;
  }

  final future = ShareService.instance.prepareContentShare(
    content,
    contentType: contentType,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final selectedThemeData =
          Provider.of<ThemeProvider>(context, listen: false).getTheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<PreparedMovieShareData>(
            future: future,
            builder: (context, snapshot) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: selectedThemeData.cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? SizedBox(
                        height: 280,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: selectedThemeData.primaryColor,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Generating share QR code...',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : snapshot.hasError
                        ? SizedBox(
                            height: 220,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: selectedThemeData.primaryColor,
                                  size: 36,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unable to prepare this share right now. Please try again.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ActionButtonWidget(
                                  label: 'Close',
                                  icon: Icons.close,
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                  },
                                ),
                              ],
                            ),
                          )
                        : _ContentShareSheetBody(
                            data: snapshot.requireData,
                            sheetContext: sheetContext,
                          ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _ContentShareSheetBody extends StatelessWidget {
  const _ContentShareSheetBody({
    required this.data,
    required this.sheetContext,
  });

  final PreparedMovieShareData data;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    final selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: false).getTheme;
    final universalLinkStr = data.qrLink.toString();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.movie.title ?? 'Share Content',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: selectedThemeData.primaryColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /// ONE UNIVERSAL QR CODE DISPLAY
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: universalLinkStr,
                size: 210,
                version: QrVersions.auto,
                backgroundColor: const Color(0xFF111111),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.white,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            "Scan to watch on Filmytell",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selectedThemeData.canvasColor.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(height: 10),

          /// CLEAN UNIVERSAL LINK TEXT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selectedThemeData.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              universalLinkStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: selectedThemeData.canvasColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// ACTION BUTTONS: [ COPY LINK ] and [ SHARE ]
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: selectedThemeData.primaryColor,
                      side: BorderSide(
                        color: selectedThemeData.primaryColor.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: universalLinkStr),
                      );
                      if (!context.mounted) return;
                      CustomToast.show(
                        context,
                        "Universal link copied to clipboard",
                        isSuccess: true,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      "Copy Link",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedThemeData.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await _shareUniversalContent(context, data);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(
                      "Share",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// SHARE UNIVERSAL CONTENT
  Future<void> _shareUniversalContent(
    BuildContext context,
    PreparedMovieShareData data,
  ) async {
    try {
      final message = data.message;

      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            text: message,
            subject: data.movie.title ?? 'Filmytell',
          ),
        );
        return;
      }

      final paths = await ShareService.instance.downloadAllQrImages(data);

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: data.movie.title ?? 'Filmytell',
          files: paths.map((path) => XFile(path)).toList(),
        ),
      );
    } catch (e) {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: data.qrLink.toString()));
        if (!context.mounted) return;
        CustomToast.show(
          context,
          "Share link copied to clipboard",
          isSuccess: true,
        );
        return;
      }

      if (!context.mounted) return;
      CustomToast.show(
        context,
        "Failed to share content",
        isSuccess: false,
      );
    }
  }
}
