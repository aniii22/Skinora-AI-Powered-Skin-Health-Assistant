import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import 'package:image_picker/image_picker.dart';

import '../auth/premium_screen.dart' show PremiumScreen;
import '../auth/session.dart';
import '../services/api_client.dart' show ApiException;
import '../services/skin_ai_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Product types suggested by the last scan in this app session. They are sent
/// with the next scan so the AI does not simply repeat itself.
List<String> _productTypesStore = <String>[];
String? _productTypesOwner;

/// Kept per account: a different sign-in starts with an empty list.
List<String> get _lastProductTypes {
  final who = Session.I.user?.email;
  if (_productTypesOwner != who) {
    _productTypesOwner = who;
    _productTypesStore = <String>[];
  }
  return _productTypesStore;
}

set _lastProductTypes(List<String> v) {
  _productTypesOwner = Session.I.user?.email;
  _productTypesStore = v;
}

class _Pic {
  _Pic(this.file, this.bytes);
  final XFile file;
  final Uint8List bytes;
}

class SkinScanScreen extends StatefulWidget {
  const SkinScanScreen({super.key});
  @override
  State<SkinScanScreen> createState() => _SkinScanScreenState();
}

class _SkinScanScreenState extends State<SkinScanScreen> {
  static const _maxPhotos = 3;
  static const _maxPhotoBytes = 2 * 1024 * 1024;
  static const _maxVideoBytes = 25 * 1024 * 1024;
  static const _types = ['oily', 'dry', 'combination', 'normal', 'sensitive'];
  static const _stages = [
    'Checking your photos...',
    'Reading your skin...',
    'Matching it with your profile...',
    'Building your routine...',
  ];

  final _picker = ImagePicker();
  final _ai = SkinAiService();
  final _note = TextEditingController();
  final _resultKey = GlobalKey();
  final List<_Pic> _pics = [];
  XFile? _video;
  int _videoBytes = 0;
  String? _skinType;
  bool _consent = false, _busy = false, _premiumGate = false;
  bool _profileApplied = false;
  String? _error;
  SkinScanResult? _result;
  Timer? _tick;
  int _stage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileApplied) return;
    _profileApplied = true;
    final t = AppScope.read(context).profile.skinType.toLowerCase();
    if (_types.contains(t)) _skinType = t;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _note.dispose();
    super.dispose();
  }

  String _pretty(String s) {
    final t = s.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  String? _photoProblem(XFile f, Uint8List bytes) {
    final n = f.name.toLowerCase();
    final dot = n.lastIndexOf('.');
    if (dot >= 0) {
      const ok = ['.jpg', '.jpeg', '.png', '.webp'];
      if (!ok.contains(n.substring(dot))) {
        return 'Please use a JPEG, PNG or WebP photo.';
      }
    }
    if (bytes.length > _maxPhotoBytes) {
      return 'Each photo must be 2 MB or smaller.';
    }
    return null;
  }

  void _startProgress() {
    _stage = 0;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_stage < _stages.length - 1) setState(() => _stage++);
    });
  }

  void _stopProgress() {
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _pick(ImageSource src) async {
    if (_busy || _pics.length >= _maxPhotos) return;
    try {
      final f = await _picker.pickImage(
        source: src,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 60,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      final problem = _photoProblem(f, bytes);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      setState(() {
        _pics.add(_Pic(f, bytes));
        _video = null;
        _result = null;
        _error = null;
        _premiumGate = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera or gallery.');
      }
    }
  }

  Future<void> _pickVideo(ImageSource src) async {
    if (_busy) return;
    try {
      final f = await _picker.pickVideo(
        source: src,
        maxDuration: const Duration(seconds: 15),
      );
      if (f == null) return;
      final size = await f.length();
      if (!mounted) return;
      if (size > _maxVideoBytes) {
        setState(
          () => _error = 'That video is larger than 25 MB. Use a shorter one (10 to 15 seconds).',
        );
        return;
      }
      setState(() {
        _video = f;
        _videoBytes = size;
        _pics.clear();
        _result = null;
        _error = null;
        _premiumGate = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera or gallery.');
      }
    }
  }

  String _noteForServer() {
    var note = _note.text.trim();
    if (_lastProductTypes.isNotEmpty) {
      final list = _lastProductTypes.take(6).join(', ');
      final short = list.length > 180 ? list.substring(0, 180) : list;
      final prev = 'Earlier suggested product types: $short.';
      note = note.isEmpty ? prev : '$note | $prev';
    }
    return note;
  }

  Future<void> _analyze() async {
    if (_busy || !_consent || (_pics.isEmpty && _video == null)) return;
    setState(() {
      _busy = true;
      _error = null;
      _premiumGate = false;
      _result = null;
    });
    _startProgress();
    try {
      final note = _noteForServer();
      final SkinScanResult r;
      if (_video != null) {
        r = await _ai.analyzeVideo(_video!, skinType: _skinType, note: note);
      } else {
        r = await _ai.analyze(
          _pics.map((p) => p.file).toList(),
          skinType: _skinType,
          note: note,
        );
      }
      if (!mounted) return;
      _lastProductTypes = r.products.map((p) => p.type).toList();
      setState(() => _result = r);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _resultKey.currentContext;
        if (c != null) {
          Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.replaceFirst('Premium: ', '');
          _premiumGate = e.premiumRequired;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      _stopProgress();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(Widget child) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0x1F000000)),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _title(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: AppText.sectionTitle)),
    ],
  );

  Widget _bullets(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final s in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\u2022  '),
              Expanded(child: Text(s)),
            ],
          ),
        ),
    ],
  );

  Widget _numbered(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}.  ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Expanded(child: Text(items[i])),
            ],
          ),
        ),
    ],
  );

  Widget _intro() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(Icons.auto_awesome, 'Check your skin with AI'),
        const SizedBox(height: 8),
        const Text(
          'Take 1-3 clear photos or one short video (bare face, daylight, '
          'close-up, hold steady). You get what the AI sees on YOUR skin, '
          'possible causes, what to do, and product types to look for. '
          'This is general guidance, not a medical diagnosis.',
          style: AppText.bodyMuted,
        ),
      ],
    ),
  );

  Widget _profileCard() {
    final p = AppScope.of(context).profile;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.person_outline_rounded, 'Personalised for you'),
          const SizedBox(height: 8),
          if (!p.isSet)
            const Text(
              'Set up your skin profile on the Home screen so advice can match '
              'your skin type and concerns.',
              style: AppText.bodyMuted,
            )
          else ...[
            const Text(
              'Your saved profile is used to personalise this scan.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('${_pretty(p.skinType)} skin')),
                if (p.sensitive) const Chip(label: Text('Sensitive')),
                for (final c in p.concerns) Chip(label: Text(_pretty(c))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _photos() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          Icons.photo_camera_outlined,
          'Your photos (${_pics.length}/$_maxPhotos)',
        ),
        if (_pics.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _pics.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _pics[i].bytes,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: _busy
                            ? null
                            : () => setState(() {
                                _pics.removeAt(i);
                                _result = null;
                              }),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.danger,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy || _pics.length >= _maxPhotos
                  ? null
                  : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _pics.length >= _maxPhotos
                  ? null
                  : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _videoCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(Icons.videocam_outlined, 'Or use a short video'),
        const SizedBox(height: 6),
        const Text(
          'Turn your face slowly left and right for 10 to 15 seconds in daylight. '
          'We pick the 3 clearest frames. Max 25 MB. Photos and video cannot be mixed.',
          style: AppText.bodyMuted,
        ),
        if (_video != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.movie_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_video!.name.isEmpty ? 'video' : _video!.name} '
                  '(${(_videoBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: Lang.I.tr('Remove video'),
                icon: const Icon(Icons.close),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _video = null;
                        _result = null;
                      }),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickVideo(ImageSource.camera),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record video'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickVideo(ImageSource.gallery),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Pick video'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _details() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(Icons.tune_rounded, 'Skin type for this scan'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in _types)
              ChoiceChip(
                checkmarkColor: Colors.white,
                label: Text(
                  _pretty(t),
                  style: TextStyle(
                    color: (_skinType == t)
                        ? Colors.white
                        : const Color(0xFF39205F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: _skinType == t,
                onSelected: _busy
                    ? null
                    : (v) => setState(() => _skinType = v ? t : null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              'Common problems',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF39205F),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to add, tap again to remove.',
              style: TextStyle(fontSize: 12, color: Color(0xFF81778F)),
            ),
            const SizedBox(height: 12),
            _ProblemChips(controller: _note, enabled: !_busy),
            const SizedBox(height: 22),
            TextField(
              controller: _note,
              enabled: !_busy,
              maxLength: 300,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: Lang.I.tr(
                  'Anything specific? (optional, e.g. pimples on cheeks)',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _doctorBanner(SkinScanResult r) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.danger),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.medical_services_outlined, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            r.seeDoctorReason.isEmpty
                ? 'Please consult a dermatologist to be safe.'
                : 'See a dermatologist: ${r.seeDoctorReason}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _confidenceBadge(String c) {
    if (c.isEmpty) return const SizedBox.shrink();
    final color = c == 'high'
        ? const Color(0xFF2E9E5B)
        : c == 'low'
        ? const Color(0xFFE5484D)
        : const Color(0xFFE8B008);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Photo quality: $c',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _productTile(ScanProduct p) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.lavender,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.type,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        if (p.keyIngredients.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final i in p.keyIngredients)
                Chip(
                  label: Text(i, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                ),
            ],
          ),
        ],
        if (p.why.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Why: ${p.why}'),
        ],
        if (p.usage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('How to use: ${p.usage}', style: AppText.bodyMuted),
        ],
      ],
    ),
  );

  Widget _listCard(IconData icon, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(icon, title),
          const SizedBox(height: 10),
          _bullets(items),
        ],
      ),
    );
  }

  Widget _routineCard(IconData icon, String title, List<String> steps) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(icon, title),
          const SizedBox(height: 10),
          _numbered(steps),
        ],
      ),
    );
  }

  Widget _precautions(SkinScanResult r) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(Icons.shield_outlined, 'Important precautions'),
        const SizedBox(height: 10),
        _bullets([
          ...r.avoid,
          'Patch test any new product on a small area first.',
          'Use sunscreen every morning.',
          'Stop a product that stings, burns or causes redness.',
          'See a dermatologist for spots that bleed, change quickly or do not heal.',
        ]),
        const SizedBox(height: 6),
        const Text(
          'This is general skincare guidance from photos. It is not a medical '
          'diagnosis and can miss things.',
          style: AppText.bodyMuted,
        ),
      ],
    ),
  );

  Widget _resultView(SkinScanResult r) {
    final unsure = r.confidence == 'low' || r.confidence == 'medium';
    final premium = Session.I.user?.isPremium == true;
    return Column(
      key: _resultKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (r.seeDoctor) _doctorBanner(r),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title(Icons.search_rounded, 'Skin overview'),
              const SizedBox(height: 8),
              _confidenceBadge(r.confidence),
              Text(r.summary.isEmpty ? 'No summary available.' : r.summary),
              if (r.concerns.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [for (final c in r.concerns) Chip(label: Text(c))],
                ),
              ],
              if (unsure) ...[
                const SizedBox(height: 10),
                Text(
                  r.confidence == 'low'
                      ? 'The photo quality was low, so treat this as a rough estimate. Try daylight, a closer shot and no filter.'
                      : 'This is an estimate from photos and may miss things.',
                  style: AppText.bodyMuted,
                ),
              ],
            ],
          ),
        ),
        _listCard(
          Icons.visibility_outlined,
          'Observed skin characteristics',
          r.observations,
        ),
        _listCard(
          Icons.help_outline_rounded,
          'Possible causes',
          r.possibleCauses,
        ),
        if (r.recommendations.isNotEmpty || r.lifestyle.isNotEmpty)
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(
                  Icons.check_circle_outline_rounded,
                  'Skincare suggestions',
                ),
                if (r.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _bullets(r.recommendations),
                ],
                if (r.lifestyle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Daily habits',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  _bullets(r.lifestyle),
                ],
              ],
            ),
          ),
        if (r.products.isNotEmpty)
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(
                  Icons.shopping_bag_outlined,
                  'Recommended product categories',
                ),
                for (final p in r.products) _productTile(p),
              ],
            ),
          ),
        _routineCard(
          Icons.wb_sunny_outlined,
          'Morning routine',
          r.routineMorning,
        ),
        _routineCard(
          Icons.nightlight_round,
          'Evening routine',
          r.routineEvening,
        ),
        _precautions(r),
        if (r.scansLeft != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              premium
                  ? 'AI scans left this month: ${r.scansLeft}'
                  : 'Free AI scans left this month: ${r.scansLeft}',
              style: AppText.bodyMuted,
            ),
          ),
        if (r.disclaimer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(r.disclaimer, style: AppText.bodyMuted),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = _pics.isNotEmpty || _video != null;
    final canRun = _consent && hasInput && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Skin Scan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _intro(),
                _profileCard(),
                _photos(),
                _videoCard(),
                _details(),
                CheckboxListTile(
                  value: _consent,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _consent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I agree to send these photos or video frames to an external AI service for analysis. '
                    'Skinora does not save them, but the AI provider may handle them under its own policy.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        if (_premiumGate)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PremiumScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.workspace_premium),
                              label: const Text('See Premium'),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canRun ? _analyze : null,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_busy ? 'Analyzing...' : 'Analyze my skin'),
                  ),
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(minHeight: 6),
                        ),
                        const SizedBox(height: 8),
                        Text(_stages[_stage], style: AppText.bodyMuted),
                      ],
                    ),
                  ),
                if (_result != null) _resultView(_result!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick-pick problem chips for the "Anything specific?" box.
/// Tap = adds the problem once. Tap again = removes it. The state is read
/// from the text box itself, so it can never be added twice.
class _ProblemChips extends StatelessWidget {
  const _ProblemChips({required this.controller, this.enabled = true});

  final TextEditingController controller;
  final bool enabled;

  static const _options = [
    'Acne',
    'Dark spots',
    'Dryness',
    'Redness',
    'Dullness',
    'Large pores',
  ];

  List<String> _parts() => controller.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _toggle(String label, bool on) {
    final parts = _parts();
    final key = label.toLowerCase();
    parts.removeWhere((p) => p.toLowerCase() == key);
    if (on) parts.add(label);
    final text = parts.join(', ');
    if (on && text.length > 300) return; // keep the note within its 300 character limit
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, _, _) {
        final chosen = _parts().map((e) => e.toLowerCase()).toSet();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in _options)
              FilterChip(
                label: Text(
                  o,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: chosen.contains(o.toLowerCase())
                        ? Colors.white
                        : const Color(0xFF39205F),
                  ),
                ),
                selected: chosen.contains(o.toLowerCase()),
                showCheckmark: false,
                selectedColor: const Color(0xFF4A1D5C),
                backgroundColor: const Color(0xFFF6EDDF),
                side: BorderSide(
                  color: chosen.contains(o.toLowerCase())
                      ? const Color(0xFF4A1D5C)
                      : const Color(0xFFE6D9C0),
                ),
                onSelected: enabled ? (v) => _toggle(o, v) : null,
              ),
          ],
        );
      },
    );
  }
}
