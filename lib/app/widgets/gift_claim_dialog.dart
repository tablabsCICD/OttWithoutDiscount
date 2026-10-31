import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:ott/app/provider/giftProvider.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

Future<bool?> showGiftClaimDialog(
  BuildContext context, {
  String? initialCouponCode,
}) {
  final theme = Theme.of(context);
  final couponCodeController = TextEditingController(
    text: _normalizeCouponCode(initialCouponCode ?? ''),
  );

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      bool isClaiming = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: ResponsiveWidget.isMobile(dialogContext)
                    ? double.infinity
                    : 400,
                child: Stack(
                  children: [
                    Positioned.fill(
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
                        Text(
                          "Enter Gift Card Number",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.canvasColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CustomTextField(
                          backgroundColor: theme.scaffoldBackgroundColor,
                          isDigits: false,
                          controller: couponCodeController,
                          autofocus: ResponsiveWidget.isTabletOrTv(dialogContext),
                          textInputAction: TextInputAction.done,
                          hintText: "Enter 16 Digit Number",
                          textInputType: TextInputType.text,
                          capitalization: TextCapitalization.characters,
                          readOnly: true,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isClaiming
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: theme.canvasColor.withOpacity(0.7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: isClaiming
                                  ? null
                                  : () async {
                                      if (isClaiming) return;

                                      final couponCode = _normalizeCouponCode(
                                        couponCodeController.text,
                                      );

                                      if (couponCode.isEmpty ||
                                          couponCode.length != 16) {
                                        CustomToast.show(
                                          dialogContext,
                                          "Invalid gift card code. Please check and try again.",
                                          isSuccess: false,
                                        );
                                        return;
                                      }

                                      setDialogState(() => isClaiming = true);

                                      try {
                                        final provider =
                                            Provider.of<GiftProvider>(
                                          dialogContext,
                                          listen: false,
                                        );
                                        final result =
                                            await provider.useGiftByCoupon(
                                          couponCode,
                                        );
                                        if (!dialogContext.mounted) return;

                                        if (result["success"] == true) {
                                          await GiftDeepLinkService.instance
                                              .markGiftCodeClaimed(couponCode);
                                          if (!dialogContext.mounted) return;
                                          CustomToast.show(
                                            dialogContext,
                                            "Gift card claimed successfully!",
                                            isSuccess: true,
                                          );
                                          Navigator.pop(dialogContext, true);
                                        } else {
                                          final rawMsg = result["message"]
                                                  ?.toString() ??
                                              "";
                                          final statusCode =
                                              result["statusCode"] as int?;
                                          final errorMessage =
                                              resolveClaimErrorMessage(
                                            rawMessage: rawMsg,
                                            statusCode: statusCode,
                                            error: result["error"],
                                          );

                                          final lower = rawMsg.toLowerCase();
                                          if (lower.contains('already') ||
                                              lower.contains('redeemed') ||
                                              lower.contains('claimed') ||
                                              lower.contains('used')) {
                                            await GiftDeepLinkService.instance
                                                .markGiftCodeClaimed(couponCode);
                                          }
                                          if (!dialogContext.mounted) return;
                                          CustomToast.show(
                                            dialogContext,
                                            errorMessage,
                                            isSuccess: false,
                                          );
                                        }
                                      } catch (error) {
                                        if (!dialogContext.mounted) return;
                                        final errorMessage =
                                            resolveClaimErrorMessage(
                                          error: error,
                                        );
                                        CustomToast.show(
                                          dialogContext,
                                          errorMessage,
                                          isSuccess: false,
                                        );
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                              () => isClaiming = false);
                                        }
                                      }
                                    },
                              child: isClaiming
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      "Redeem",
                                      style: TextStyle(color: Colors.white),
                                    ),
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
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      couponCodeController.dispose();
    });
  });
}

String resolveClaimErrorMessage({
  dynamic error,
  String? rawMessage,
  int? statusCode,
}) {
  if (error != null) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socket') ||
        errStr.contains('network') ||
        errStr.contains('connection') ||
        errStr.contains('host lookup') ||
        errStr.contains('timed out') ||
        errStr.contains('clientexception')) {
      return "Unable to claim the gift card. Please check your internet connection and try again.";
    }
    return "Something went wrong while claiming the gift card. Please try again later.";
  }

  if (statusCode != null && statusCode >= 500) {
    return "Something went wrong while claiming the gift card. Please try again later.";
  }

  final msg = rawMessage?.trim() ?? '';
  final lower = msg.toLowerCase();

  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('host lookup') ||
      lower.contains('timed out') ||
      lower.contains('unable to claim')) {
    return "Unable to claim the gift card. Please check your internet connection and try again.";
  }

  if (lower.contains('already') ||
      lower.contains('claimed') ||
      lower.contains('redeemed') ||
      lower.contains('used')) {
    return "This gift card has already been claimed.";
  }

  if (lower.contains('expire') ||
      lower.contains('validity') ||
      lower.contains('outdated')) {
    return "This gift card has expired.";
  }

  if (lower.contains('invalid') ||
      lower.contains('not found') ||
      lower.contains('not exist') ||
      lower.contains('does not exist') ||
      lower.contains('incorrect') ||
      lower.contains('wrong')) {
    return "Invalid gift card code. Please check and try again.";
  }

  if (lower.contains('server error') ||
      lower.contains('internal server') ||
      lower.contains('something went wrong')) {
    return "Something went wrong while claiming the gift card. Please try again later.";
  }

  if (msg.isNotEmpty &&
      !lower.contains('failed to save gift') &&
      !lower.contains('failed to claim')) {
    return msg;
  }

  return "Something went wrong while claiming the gift card. Please try again later.";
}

String _normalizeCouponCode(String value) {
  return value.trim().replaceAll(' ', '').toUpperCase();
}
