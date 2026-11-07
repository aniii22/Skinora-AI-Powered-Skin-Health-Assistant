import 'package:flutter/material.dart';
import '../utils/format.dart';

import '../services/api_client.dart';
import '../services/local_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart' show confirmDialog, showSnack;

final ApiClient _api = ApiClient();

List<String> get _dayNames => weekdayNames();

class Reminder {
  Reminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.time,
    required this.days,
    required this.enabled,
  });
  final int id;
  final String kind, title, time;
  final int days;
  final bool enabled;

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: (j['id'] as num).toInt(),
    kind: j['kind'] as String,
    title: (j['title'] as String?) ?? '',
    time: j['time'] as String,
    days: (j['days'] as num).toInt(),
    enabled: j['enabled'] == true,
  );

  String get label {
    switch (kind) {
      case 'water':
        return 'Drink water';
      case 'morning':
        return 'Morning skincare';
      case 'evening':
        return 'Evening skincare';
      default:
        return title.isEmpty ? 'Custom reminder' : title;
    }
  }
}

String _daysLabel(int m) {
  if (m == 127) return 'Every day';
  if (m == 31) return 'Weekdays';
  if (m == 96) return 'Weekends';
  final out = <String>[];
  for (var i = 0; i < 7; i++) {
    if ((m & (1 << i)) != 0) out.add(_dayNames[i]);
  }
  return out.join(', ');
}

(IconData, Color) _kindStyle(String k) {
  switch (k) {
    case 'water':
      return (Icons.water_drop_rounded, AppColors.water);
    case 'morning':
      return (Icons.wb_sunny_rounded, AppColors.journal);
    case 'evening':
      return (Icons.nightlight_round, AppColors.sleep);
    default:
      return (Icons.alarm_rounded, AppColors.primary);
  }
}

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parse(String s) => TimeOfDay(
  hour: int.tryParse(s.substring(0, 2)) ?? 0,
  minute: int.tryParse(s.substring(3, 5)) ?? 0,
);

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _loading = true;
  String? _error;
  List<Reminder> _items = [];
  bool _all = true, _quiet = false;
  String _qs = '22:00', _qe = '07:00';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final m = (await _api.request('GET', '/api/reminders')) as Map<String, dynamic>;
      final p = m['prefs'] as Map<String, dynamic>;
      final list = (m['items'] as List)
          .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _all = p['all_enabled'] == true;
        _quiet = p['quiet_enabled'] == true;
        _qs = p['quiet_start'] as String;
        _qe = p['quiet_end'] as String;
        _error = null;
        _loading = false;
      });
      LocalNotifier.I.syncFromServer(_api);
      final off = (p['tz_offset_min'] as num?)?.toInt();
      if (off != DateTime.now().timeZoneOffset.inMinutes) _savePrefs();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load reminders.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePrefs() async {
    await _savePrefsRaw();
    LocalNotifier.I.syncFromServer(_api);
  }

  Future<void> _savePrefsRaw() async {
    try {
      await _api.request(
        'PUT',
        '/api/notification-prefs',
        body: {
          'all_enabled': _all,
          'quiet_enabled': _quiet,
          'quiet_start': _qs,
          'quiet_end': _qe,
          'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _pickQuiet(bool start) async {
    final t = await showTimePicker(
      context: context,
      initialTime: _parse(start ? _qs : _qe),
    );
    if (t == null) return;
    setState(() {
      if (start) {
        _qs = _hhmm(t);
      } else {
        _qe = _hhmm(t);
      }
    });
    await _savePrefs();
  }

  Future<void> _toggle(Reminder r, bool v) async {
    try {
      await _api.request(
        'PUT',
        '/api/reminders/${r.id}',
        body: {
          'kind': r.kind,
          'title': r.title,
          'time': r.time,
          'days': r.days,
          'enabled': v,
        },
      );
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _openForm([Reminder? r]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReminderForm(existing: r),
    );
    if (saved == true) await _load(silent: true);
  }

  Future<void> _test() async {
    try {
      await _api.request('POST', '/api/notifications/test');
      await LocalNotifier.I.testNow();
      if (mounted) showSnack(context, 'Test notification added. Check the bell.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Widget _card(Reminder r) {
    final (icon, color) = _kindStyle(r.kind);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openForm(r),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
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
                    Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text('${r.time}  \u00B7  ${_daysLabel(r.days)}', style: AppText.caption),
                  ],
                ),
              ),
              Switch(value: r.enabled, onChanged: (v) => _toggle(r, v)),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All notifications', style: AppText.cardTitle),
                subtitle: const Text('Turn off to pause every reminder', style: AppText.caption),
                value: _all,
                onChanged: (v) {
                  setState(() => _all = v);
                  _savePrefs();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Quiet hours', style: AppText.cardTitle),
                subtitle: const Text('No reminders during this time', style: AppText.caption),
                value: _quiet,
                onChanged: (v) {
                  setState(() => _quiet = v);
                  _savePrefs();
                },
              ),
              if (_quiet)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickQuiet(true),
                        child: Text('From $_qs'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickQuiet(false),
                        child: Text('To $_qe'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('YOUR REMINDERS', style: AppText.label),
        const SizedBox(height: 10),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No reminders yet. Tap "Add reminder" to create a water or skincare reminder.',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted,
            ),
          ),
        for (final r in _items) ...[_card(r), const SizedBox(height: 10)],
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _test,
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Send test notification'),
          ),
        ),
        const Text(
          'Reminders appear in your notification list and as phone notifications at the chosen time.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add reminder'),
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

class _ReminderForm extends StatefulWidget {
  const _ReminderForm({this.existing});
  final Reminder? existing;
  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late String _kind;
  late TimeOfDay _time;
  late int _days;
  late final TextEditingController _title;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _kind = r?.kind ?? 'water';
    _time = r == null ? const TimeOfDay(hour: 10, minute: 0) : _parse(r.time);
    _days = r?.days ?? 127;
    _title = TextEditingController(text: r?.title ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _setKind(String k) {
    setState(() {
      _kind = k;
      if (widget.existing == null) {
        _time = k == 'morning'
            ? const TimeOfDay(hour: 7, minute: 30)
            : k == 'evening'
            ? const TimeOfDay(hour: 21, minute: 0)
            : const TimeOfDay(hour: 10, minute: 0);
      }
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_days == 0) {
      setState(() => _error = 'Select at least one day.');
      return;
    }
    if (_kind == 'custom' && _title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title for the custom reminder.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {
      'kind': _kind,
      'title': _kind == 'custom' ? _title.text.trim() : '',
      'time': _hhmm(_time),
      'days': _days,
      'enabled': widget.existing?.enabled ?? true,
    };
    try {
      final r = widget.existing;
      if (r == null) {
        await _api.request('POST', '/api/reminders', body: body);
      } else {
        await _api.request('PUT', '/api/reminders/${r.id}', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final r = widget.existing;
    if (r == null || _busy) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete reminder?',
      message: 'This reminder will stop immediately.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.request('DELETE', '/api/reminders/${r.id}');
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const kinds = [
      ('water', 'Water'),
      ('morning', 'Morning'),
      ('evening', 'Evening'),
      ('custom', 'Custom'),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.existing == null ? 'New reminder' : 'Edit reminder', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final k in kinds)
                ChoiceChip(
                  label: Text(k.$2),
                  selected: _kind == k.$1,
                  onSelected: (_) => _setKind(k.$1),
                ),
            ],
          ),
          if (_kind == 'water')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('The message uses your saved glass size.', style: AppText.caption),
            ),
          if (_kind == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Reminder title'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            icon: const Icon(Icons.access_time_rounded),
            label: Text('Time: ${_hhmm(_time)}'),
          ),
          const SizedBox(height: 12),
          const Text('REPEAT ON', style: AppText.label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(_dayNames[i]),
                  selected: (_days & (1 << i)) != 0,
                  onSelected: (v) => setState(() {
                    _days = v ? (_days | (1 << i)) : (_days & ~(1 << i));
                  }),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                TextButton(
                  onPressed: _busy ? null : _delete,
                  child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}