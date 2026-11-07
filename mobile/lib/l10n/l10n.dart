import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';
import 'strings_extra.dart';

/// App language. Codes: en, hi, mr.
class Lang extends ChangeNotifier {
  Lang._() {
    _load();
  }
  static final Lang I = Lang._();
  static const codes = ['en', 'hi', 'mr'];

  String code = 'en';

  /// Marks every live widget dirty so plain-String labels (hints, tooltips,
  /// nav labels) pick up the new language, not only Text widgets.
  static void _rebuildAll() {
    try {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      root.visitChildren(visit);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString('app_lang');
      if (c != null && codes.contains(c) && c != code) {
        code = c;
        notifyListeners();
        _rebuildAll();
      }
    } catch (_) {}
  }

  Future<void> set(String c) async {
    if (!codes.contains(c)) return;
    code = c;
    notifyListeners();
    _rebuildAll();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('app_lang', c);
    } catch (_) {}
  }

  static final _num = RegExp(r'\d+(?:\.\d+)?');
  static final _ws = RegExp(r'\s+');

  static String _norm(String s) => s
      .replaceAll('\u2019', "'")
      .replaceAll(_ws, ' ')
      .trim()
      .toLowerCase();

  static Map<String, List<String>>? _idx;

  /// Lookup table. Case and spacing insensitive. Existing kTr entries win,
  /// kTrExtra fills the gaps.
  static Map<String, List<String>> get _index {
    final cached = _idx;
    if (cached != null) return cached;
    final idx = <String, List<String>>{};
    kTrExtra.forEach((k, v) => idx[_norm(k)] = List<String>.from(v));
    kTr.forEach((k, v) => idx[_norm(k)] = List<String>.from(v));
    return _idx = idx;
  }

  List<String>? _find(String s) {
    final n = _norm(s);
    if (n.isEmpty) return null;
    return _index[n];
  }

  String? _withNumbers(String s, int i) {
    final n = _norm(s);
    final nums = _num.allMatches(n).map((x) => x.group(0)!).toList();
    if (nums.isEmpty) return null;
    final h = _index[n.replaceAll(_num, '{}')];
    if (h == null) return null;
    var out = h[i];
    for (var k = 0; k < nums.length; k++) {
      out = out.replaceAll('{$k}', nums[k]);
    }
    var k = 0;
    out = out.replaceAllMapped('{}', (_) => k < nums.length ? nums[k++] : '');
    return out;
  }

  String? _piece(String p, int i) {
    final a = _find(p);
    if (a != null) return a[i];
    return _withNumbers(p, i);
  }

  /// "A: B", "A · B", "A • B", "A, B" -> translate each side.
  String? _split(String s, int i) {
    final t = s.replaceAll('\u00A0', ' ');
    for (final sep in const [' \u00B7 ', ' \u2022 ', ': ', ', ', ' / ', ' - ']) {
      if (!t.contains(sep)) continue;
      var any = false;
      final out = t.split(sep).map((p) {
        final x = _piece(p, i);
        if (x != null) {
          any = true;
          return x;
        }
        return p;
      }).join(sep);
      if (any) return out;
    }
    return null;
  }

  /// English text in, chosen language out. Unknown text stays English.
  String tr(String s) {
    if (code == 'en' || s.trim().isEmpty) return s;
    final i = code == 'hi' ? 0 : 1;
    final a = _find(s);
    if (a != null) return a[i];
    final b = _withNumbers(s, i);
    if (b != null) return b;
    final c = _split(s, i);
    if (c != null) return c;
    if (kDebugMode && RegExp(r'[A-Za-z]{3,}').hasMatch(s)) {
      debugPrint('[i18n missing:$code] $s');
    }
    return s;
  }
}

/// Drop-in replacement for Flutter's Text. It translates itself.
class Text extends StatefulWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  State<Text> createState() => _TextState();
}

class _TextState extends State<Text> {
  @override
  void initState() {
    super.initState();
    Lang.I.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Lang.I.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    if (w.textSpan != null) {
      return m.Text.rich(
        w.textSpan!,
        style: w.style,
        strutStyle: w.strutStyle,
        textAlign: w.textAlign,
        textDirection: w.textDirection,
        locale: w.locale,
        softWrap: w.softWrap,
        overflow: w.overflow,
        textScaler: w.textScaler,
        maxLines: w.maxLines,
        semanticsLabel: w.semanticsLabel,
        textWidthBasis: w.textWidthBasis,
        textHeightBehavior: w.textHeightBehavior,
        selectionColor: w.selectionColor,
      );
    }
    return m.Text(
      Lang.I.tr(w.data ?? ''),
      style: w.style,
      strutStyle: w.strutStyle,
      textAlign: w.textAlign,
      textDirection: w.textDirection,
      locale: w.locale,
      softWrap: w.softWrap,
      overflow: w.overflow,
      textScaler: w.textScaler,
      maxLines: w.maxLines,
      semanticsLabel: w.semanticsLabel,
      textWidthBasis: w.textWidthBasis,
      textHeightBehavior: w.textHeightBehavior,
      selectionColor: w.selectionColor,
    );
  }
}

const _options = [('en', 'English'), ('hi', 'हिन्दी'), ('mr', 'मराठी')];

/// Bottom sheet to choose the app language.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListenableBuilder(
        listenable: Lang.I,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            for (final o in _options)
              ListTile(
                title: Text(
                  o.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Lang.I.code == o.$1
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () {
                  Lang.I.set(o.$1);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}