import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/network/api_helper.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/pages/notification%20page/NotificationDetailPage.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/ott_tv_focus.dart';
import 'package:ott/data/models/response/push_notification_response.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const int _pageSize = 20;

  final List<PushNotificationItem> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _pageNo = 0;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMore || !_hasMore)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _errorMessage = null;
        _pageNo = 0;
        _notifications.clear();
      }
    });

    try {
      final user = await LocalSharePreferences.localSharePreferences.getUser();
      final userId = user?.id;
      if (userId == null) {
        throw Exception(AppLocalizations.of(context)!.notifLoginAgain);
      }

      final response = await ApiHelper().getApi(
        ApiConstant.userPushNotifications(
          userId,
          loadMore ? _pageNo + 1 : 0,
          _pageSize,
        ),
      );

      final responseBody = _decodeBody(response.body);
      final apiMessage = responseBody['message']?.toString().trim() ??
          AppLocalizations.of(context)!.notifRequestFailed;

      if (response.statusCode != 200) {
        throw Exception(apiMessage);
      }

      final parsed = PushNotificationResponse.fromJson(responseBody);
      if (parsed.success != true) {
        throw Exception(parsed.message ?? apiMessage);
      }

      final pageData = parsed.data;
      if (pageData == null) {
        throw Exception(parsed.message ??
            AppLocalizations.of(context)!.notifNoDataReturned);
      }

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _pageNo = _pageNo + 1;
        }
        _notifications.addAll(pageData.content);
        _hasMore = pageData.last == false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(error);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = json.decode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{
        'message': AppLocalizations.of(context)!.notifInvalidServerResponse,
      };
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? AppLocalizations.of(context)!.notifUnableToFetch
        : message;
  }

  void _openNotification(PushNotificationItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(notification: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(title: lang.notification),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(),
        child: _body(selectedThemeData),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.28),
          Icon(Icons.error_outline, size: 72, color: theme.primaryColor),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.canvasColor, fontSize: 15),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton(
              onPressed: () => _loadNotifications(),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 220),
          const Icon(Icons.notifications_off, size: 80, color: Colors.grey),
          const SizedBox(height: 10),
          Center(
            child: Text(
              AppLocalizations.of(context)!.notifNoNotifications,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _notifications.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _notifications.length) {
          return Center(
            child: TextButton(
              onPressed: _isLoadingMore
                  ? null
                  : () => _loadNotifications(loadMore: true),
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context)!.loadMore),
            ),
          );
        }

        final item = _notifications[index];
        final isPending = item.deliveryStatus?.toUpperCase() == 'PENDING';

        final card = Card(
          color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            onTap: ResponsiveWidget.isMobile(context)
                ? () => _openNotification(item)
                : null,
            leading: CircleAvatar(
              backgroundColor: isPending
                  ? Colors.orange.withOpacity(0.2)
                  : theme.primaryColor.withOpacity(0.2),
              child: Icon(
                isPending ? Icons.schedule : Icons.notifications_active,
                color: isPending ? Colors.orange : theme.primaryColor,
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.canvasColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.canvasColor.withOpacity(0.7)),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );

        if (ResponsiveWidget.isMobile(context)) return card;

        return OttTvFocus(
          onTap: () => _openNotification(item),
          borderRadius: 8,
          scale: 1.02,
          child: card,
        );
      },
    );
  }
}
