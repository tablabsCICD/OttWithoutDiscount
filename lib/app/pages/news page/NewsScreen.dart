import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class NewsScreenArgs {
  const NewsScreenArgs({
    this.title,
    this.body,
    required this.payload,
  });

  /// Notification title/body; null when the notification had none (a
  /// localized fallback is shown on screen).
  final String? title;
  final String? body;
  final Map<String, dynamic> payload;

  factory NewsScreenArgs.fromMap(Map<String, dynamic> map) {
    final rawPayload = map['payload'];

    return NewsScreenArgs(
      title: map['title']?.toString(),
      body: map['body']?.toString(),
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
              ? rawPayload.cast<String, dynamic>()
              : <String, dynamic>{},
    );
  }
}

class NewsScreen extends StatelessWidget {
  const NewsScreen({
    super.key,
    required this.args,
  });

  final NewsScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: FilmytellAppBar(
        automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
        title: lang.newsTitle,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              args.title ?? lang.newsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              args.body ?? lang.newsNoMessageBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              lang.newsPayload,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(args.payload.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
