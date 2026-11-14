import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import 'package:image_picker/image_picker.dart';

import '../auth/premium_screen.dart' show showPremiumDialog;
import '../auth/session.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/journal_widgets.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthTitle(DateTime d) => '${_months[d.month - 1]} ${d.year}';

int _monthCount(AppState s) {
  final n = DateTime.now();
  return s.journal
      .where((e) => e.day.year == n.year && e.day.month == n.month)
      .length;
}

/// Journal photo that sends the login token, so the server accepts it.
Widget _journalPhoto(BuildContext context, JournalEntry e, {double? height}) {
  final s = AppScope.read(context);
  return Image.network(
    s.api.photoUrl(e.id, e.photoVersion),
    headers: s.api.authHeaders,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    semanticLabel: 'Progress photo from ${prettyDate(e.day)}',
    loadingBuilder: (_, child, progress) {
      if (progress == null) return child;
      return Container(
        height: height ?? 120,
        alignment: Alignment.center,
        color: AppColors.panel,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    },
    errorBuilder: (_, _, _) => Container(
      height: height ?? 80,
      alignment: Alignment.center,
      color: AppColors.panel,
      child: const Text('Photo could not be loaded', style: AppText.caption),
    ),
  );
}

Widget _fullPhoto(BuildContext context, JournalEntry e) {
  final s = AppScope.read(context);
  return ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 460),
    child: Container(
      width: double.infinity,
      color: AppColors.panel,
      child: Image.network(
        s.api.photoUrl(e.id, e.photoVersion),
        headers: s.api.authHeaders,
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: 'Progress photo from ${prettyDate(e.day)}',
        errorBuilder: (_, _, _) => Container(
          height: 80,
          alignment: Alignment.center,
          child: const Text(
            'Photo could not be loaded',
            style: AppText.caption,
          ),
        ),
      ),
    ),
  );
}

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Skin Journey')),
      body: ResponsivePage(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              eyebrow: 'NOTICE & NOTE',
              title: 'Your Skin Journey',
              subtitle: 'Write down how your skin feels each day and optionally add a progress photo.',
            ),
            LoadGate(state: s, builder: () => _content(context, s)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppState s) {
    final entries = [...s.journal]..sort((a, b) => b.day.compareTo(a.day));
    final photos = entries.where((e) => e.hasPhoto).toList();

    final timeline = <Widget>[];
    String? lastMonth;
    for (final e in entries) {
      final m = _monthTitle(e.day);
      if (m != lastMonth) {
        timeline.add(
          Padding(
            padding: EdgeInsets.only(
              top: lastMonth == null ? 0 : 8,
              bottom: 10,
            ),
            child: Text(m.toUpperCase(), style: AppText.sectionTitle),
          ),
        );
        lastMonth = m;
      }
      timeline.add(_JournalTile(entry: e));
      timeline.add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JournalHeader(entries: entries, monthCount: _monthCount(s)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () {
            final premium = Session.I.user?.isPremium == true;
            if (!premium && _monthCount(s) >= 10) {
              showPremiumDialog(
                context,
                'Premium: the free plan allows 10 journal entries per month. Upgrade for unlimited entries.',
              );
              return;
            }
            openScreen(context, const JournalEditorScreen());
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('New entry'),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          const EmptyState(
            icon: Icons.auto_awesome_rounded,
            title: 'No journal entries yet',
            message: 'Your entries will appear here, newest first.',
          )
        else ...[
          _CompareCard(photos: photos),
          const SizedBox(height: 22),
          ...timeline,
        ],
        const SizedBox(height: 6),
        const InfoNote(
          'Photos are stored on your own Skinora server and are not encrypted or sent anywhere else. '
          'Deleting an entry or a photo removes the file from the server.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.entries, required this.monthCount});
  final List<JournalEntry> entries;
  final int monthCount;

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .88),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rated = entries.where((e) => e.rating != null).toList();
    final avg = rated.isEmpty
        ? null
        : rated.fold<int>(0, (a, e) => a + e.rating!) / rated.length;
    final photoCount = entries.where((e) => e.hasPhoto).length;

    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        final premium = Session.I.user?.isPremium == true;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.deep, AppColors.primary],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _stat('${entries.length}', 'Entries'),
                  _stat('$monthCount', 'This month'),
                  _stat(
                    avg == null
                        ? '-'
                        : '${moodEmoji(avg.round())} ${avg.toStringAsFixed(1)}',
                    'Avg mood',
                  ),
                  _stat('$photoCount', 'Photos'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                premium ? 'Unlimited entries' : 'Free plan: last 2 days shown. Premium unlocks your full journey.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .9),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Oldest vs newest photo, as a slider or side by side.
class _CompareCard extends StatefulWidget {
  const _CompareCard({required this.photos});

  /// Entries that have a photo, newest first.
  final List<JournalEntry> photos;

  @override
  State<_CompareCard> createState() => _CompareCardState();
}

class _CompareCardState extends State<_CompareCard> {
  bool _side = false;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.length < 2) {
      return const AppSurface(
        child: Row(
          children: [
            Icon(Icons.compare_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add photos on two different days to see your before and after comparison here.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      );
    }

    final before = photos.last;
    final after = photos.first;
    final days = DateTime.utc(after.day.year, after.day.month, after.day.day)
        .difference(DateTime.utc(before.day.year, before.day.month, before.day.day))
        .inDays;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Your progress', style: AppText.cardTitle),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Slider')),
                  ButtonSegment(value: true, label: Text('Side by side')),
                ],
                selected: {_side},
                onSelectionChanged: (v) => setState(() => _side = v.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _sideItem(context, 'BEFORE', before)),
                const SizedBox(width: 10),
                Expanded(child: _sideItem(context, 'AFTER', after)),
              ],
            )
          else
            BeforeAfterSlider(
              height: 340,
              before: _journalPhoto(context, before),
              after: _journalPhoto(context, after),
            ),
          const SizedBox(height: 10),
          Text(
            '${prettyDateYear(before.day)}  to  ${prettyDateYear(after.day)}'
            '${days > 0 ? '  ($days days)' : ''}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _sideItem(BuildContext context, String label, JournalEntry e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: .8,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _journalPhoto(context, e, height: 240),
        ),
        const SizedBox(height: 6),
        Text(prettyDate(e.day), style: AppText.caption),
      ],
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {super.key});
  final int rating;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rating $rating of 5',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 18,
              color: AppColors.journal,
            ),
        ],
      ),
    ),
  );
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final e = entry;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (e.rating != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: moodColor(e.rating).withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    moodEmoji(e.rating),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prettyDateYear(e.day), style: AppText.cardTitle),
                    if (e.rating != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        moodLabel(e.rating),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: moodColor(e.rating),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit entry from ${prettyDate(e.day)}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    openScreen(context, JournalEditorScreen(existing: e)),
              ),
              IconButton(
                tooltip: 'Delete entry from ${prettyDate(e.day)}',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete journal entry?',
                    message: e.hasPhoto
                        ? 'The note and its photo will be deleted permanently.'
                        : 'The note will be deleted permanently.',
                    confirmLabel: 'Delete',
                  );
                  if (!ok || !context.mounted) return;
                  final err = await s.deleteJournal(e.id);
                  if (!context.mounted) return;
                  showSnack(
                    context,
                    err ?? 'Entry deleted',
                    error: err != null,
                  );
                },
              ),
            ],
          ),
          if (e.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Text(e.notes, style: AppText.body),
            ),
          if (e.hasPhoto)
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _fullPhoto(context, e),
              ),
            ),
        ],
      ),
    );
  }
}

class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({super.key, this.existing});
  final JournalEntry? existing;

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  static const _quickTags = [
    'Dry',
    'Oily',
    'Breakout',
    'Redness',
    'Irritated',
    'Glowing',
    'New product',
    'Used sunscreen',
    'Poor sleep',
    'Stressed',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notes;
  final _picker = ImagePicker();
  late DateTime _day;
  int? _rating;
  XFile? _newPhoto;
  var _newBytes = Uint8List(0);
  bool _removePhoto = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _notes = TextEditingController(text: e?.notes ?? '');
    _day = e?.day ?? AppScope.read(context).today;
    _rating = e?.rating;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  List<String> _noteParts() => _notes.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Tap a tag: add it once. Tap it again: remove it.
  void _addTag(String tag) {
    final parts = _noteParts();
    final key = tag.toLowerCase();
    final has = parts.any((p) => p.toLowerCase() == key);
    parts.removeWhere((p) => p.toLowerCase() == key);
    if (!has) parts.add(tag);
    final next = parts.join(', ');
    if (!has && next.length > 2000) return;
    setState(() {
      _notes.text = next;
      _notes.selection = TextSelection.collapsed(offset: next.length);
      _error = null;
    });
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final first = Session.I.user?.isPremium == true
        ? DateTime(2020)
        : DateTime(now.year, now.month, now.day - 1);
    final d = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(first) ? first : _day,
      firstDate: first,
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) {
      setState(() => _day = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _pickPhoto() async {
    if (Session.I.user?.isPremium != true) {
      showPremiumDialog(
        context,
        'Premium: progress photos are part of Premium. Upgrade to add photos.',
      );
      return;
    }
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        setState(
          () => _error =
              'That photo is larger than 5 MB. Please choose a smaller one.',
        );
        return;
      }
      setState(() {
        _newPhoto = f;
        _newBytes = bytes;
        _removePhoto = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Could not open your photo library. Check that Skinora is allowed to access photos and try again.',
          error: true,
        );
      }
    }
  }

  Future<void> _removeExistingPhoto() async {
    final ok = await confirmDialog(
      context,
      title: 'Remove photo?',
      message:
          'The photo will be deleted from the server when you save this entry.',
      confirmLabel: 'Remove',
    );
    if (ok && mounted) setState(() => _removePhoto = true);
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_notes.text.trim().isEmpty && _rating == null) {
      setState(() => _error = 'Add a note or pick a mood first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    SaveOutcome r;
    try {
      r = await AppScope.read(context).saveJournal(
        id: widget.existing?.id,
        day: _day,
        notes: _notes.text.trim(),
        rating: _rating,
        newPhoto: _newPhoto,
        removePhoto: _removePhoto && _newPhoto == null,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = r.message;
      });
      return;
    }
    showSnack(
      context,
      r.message ?? 'Journal entry saved',
      error: r.message != null,
    );
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  Widget _photoSection(BuildContext context) {
    final e = widget.existing;
    final showExisting =
        e != null && e.hasPhoto && !_removePhoto && _newPhoto == null;
    Widget? preview;
    if (_newPhoto != null) {
      preview = Image.memory(
        _newBytes,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (showExisting) {
      preview = _fullPhoto(context, e);
    }

    if (preview == null) {
      return Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(18),
          onTap: _busy ? null : _pickPhoto,
          child: Container(
            height: 130,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to add a photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 2),
                Text('JPG or PNG, up to 5 MB', style: AppText.caption),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(18), child: preview),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Change photo'),
            ),
            if (_newPhoto != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _newPhoto = null;
                        _newBytes = Uint8List(0);
                      }),
                child: const Text('Discard new photo'),
              ),
            if (showExisting)
              TextButton(
                onPressed: _busy ? null : _removeExistingPhoto,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Remove photo'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stickyBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'New journal entry' : 'Edit journal entry',
        ),
      ),
      bottomNavigationBar: _stickyBar(),
      body: ResponsivePage(
        maxWidth: 720,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSurface(
                onTap: _busy ? null : _pickDay,
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prettyDateYear(_day),
                        style: AppText.cardTitle,
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'How does your skin feel?',
                style: AppText.sectionTitle,
              ),
              const SizedBox(height: 4),
              const Text(
                'Optional. Tap again to clear.',
                style: AppText.caption,
              ),
              const SizedBox(height: 12),
              MoodPicker(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: 22),
              const Text('Quick tags', style: AppText.sectionTitle),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: _notes,
                builder: (context, _) {
                  final chosen =
                      _noteParts().map((e) => e.toLowerCase()).toSet();
                  return QuickTags(
                    tags: _quickTags,
                    selected: chosen,
                    onTap: _addTag,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                maxLines: 8,
                minLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: Lang.I.tr('Notes'),
                  hintText: Lang.I.tr('What did you notice today?'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Progress photo (optional)',
                style: AppText.sectionTitle,
              ),
              const SizedBox(height: 10),
              _photoSection(context),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}