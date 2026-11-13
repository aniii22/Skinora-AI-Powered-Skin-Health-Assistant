import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../l10n/l10n.dart';

import '../auth/session.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart' show confirmDialog, showSnack;

final ApiClient _api = ApiClient();

/// Unread count shown on the bell badge.
final ValueNotifier<int> unreadNotifications = ValueNotifier<int>(0);

Future<Map<String, dynamic>> _fetchNotifications() async =>
    (await _api.request('GET', '/api/notifications')) as Map<String, dynamic>;

Future<void> refreshUnreadNotifications() async {
  if (!Session.I.signedIn) return;
  try {
    final m = await _fetchNotifications();
    unreadNotifications.value = (m['unread'] as num?)?.toInt() ?? 0;
  } catch (_) {}
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });
  final int id;
  final String category, title, body;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: (j['id'] as num).toInt(),
    category: (j['category'] as String?) ?? 'general',
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    isRead: j['is_read'] == true,
    createdAt:
        DateTime.tryParse((j['created_at'] as String?) ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

(IconData, Color) _categoryStyle(String c) {
  switch (c) {
    case 'water':
      return (Icons.water_drop_rounded, AppColors.water);
    case 'skincare':
      return (Icons.spa_rounded, AppColors.primary);
    case 'routine':
      return (Icons.checklist_rounded, AppColors.insight);
    case 'task':
      return (Icons.task_alt_rounded, AppColors.success);
    case 'premium':
      return (Icons.workspace_premium, AppColors.gold);
    default:
      return (Icons.notifications_rounded, AppColors.muted);
  }
}

String _when(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]}, $hh:$mm';
}

/// Bell icon with unread badge for the AppBar.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    refreshUnreadNotifications();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => refreshUnreadNotifications(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    refreshUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: unreadNotifications,
      builder: (context, n, _) => IconButton(
        tooltip: n > 0 ? 'Notifications ($n unread)' : 'Notifications',
        onPressed: _open,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, color: AppColors.deep, size: 26),
            if (n > 0)
              Positioned(
                right: -5,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    n > 99 ? '99+' : '$n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true, _busy = false;
  String? _error;
  List<AppNotification> _items = [];

  int get _unread => _items.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final m = await _fetchNotifications();
      final list = (m['items'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
        _loading = false;
      });
      unreadNotifications.value = _unread;
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load notifications.'; _loading = false; });
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await _api.request('PUT', '/api/notifications/${n.id}/read');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _markAll() async {
    if (_busy || _unread == 0) return;
    setState(() => _busy = true);
    try {
      await _api.request('POST', '/api/notifications/read-all');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy || _items.isEmpty) return;
    final ok = await confirmDialog(
      context,
      title: 'Clear all notifications?',
      message: 'Your notification history will be permanently deleted.',
      confirmLabel: 'Clear all',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.request('DELETE', '/api/notifications');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(AppNotification n) {
    final (icon, color) = _categoryStyle(n.category);
    return Material(
      color: n.isRead ? Colors.white : AppColors.lavender,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _markRead(n),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle.copyWith(
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(n.body, style: AppText.bodyMuted),
                    ],
                    const SizedBox(height: 6),
                    Text(_when(n.createdAt), style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: AppText.bodyMuted),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.lavender,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('No notifications yet', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              const Text(
                'Reminders and updates will show up here.',
                textAlign: TextAlign.center,
                style: AppText.bodyMuted,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_unread > 0 ? 'Notifications ($_unread)' : 'Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: (_busy || _unread == 0) ? null : _markAll,
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Clear history',
            onPressed: (_busy || _items.isEmpty) ? null : _clear,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _body(),
        ),
      ),
    );
  }
}