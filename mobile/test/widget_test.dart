import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('English text is returned unchanged', () {
    expect(Lang.I.tr('Daily goal (ml)'), 'Daily goal (ml)');
  });

  test('Marathi and Hindi translate known text and keep numbers', () async {
    await Lang.I.set('mr');
    expect(Lang.I.tr('Daily goal (ml)'), isNot('Daily goal (ml)'));
    expect(Lang.I.tr('Last 7 days'), contains('7'));
    await Lang.I.set('hi');
    expect(Lang.I.tr('Daily goal (ml)'), isNot('Daily goal (ml)'));
    await Lang.I.set('en');
  });
}