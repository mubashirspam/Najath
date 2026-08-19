import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najath_core/najath_core.dart';

/// The ARB files are the contract. A key present in English and missing in
/// Malayalam does not fail the build — Flutter falls back silently — so a
/// guardian would see one English word in an otherwise Malayalam screen and
/// nobody would find out. This is the check that catches it.
void main() {
  /// In a pub workspace `flutter test` runs from the workspace root, not the
  /// package, so the path is resolved rather than assumed.
  Map<String, dynamic> arb(String locale) {
    const relative = 'lib/src/l10n/arb';
    final candidates = [
      File('$relative/app_$locale.arb'),
      File('packages/core/$relative/app_$locale.arb'),
    ];

    final file = candidates.firstWhere(
      (candidate) => candidate.existsSync(),
      orElse: () => throw StateError(
        'app_$locale.arb not found from ${Directory.current.path}',
      ),
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Set<String> keysOf(Map<String, dynamic> source) =>
      source.keys.where((k) => !k.startsWith('@')).toSet();

  test('every English key has a Malayalam translation', () {
    final en = keysOf(arb('en'));
    final ml = keysOf(arb('ml'));

    expect(en.difference(ml), isEmpty, reason: 'missing from app_ml.arb');
    expect(ml.difference(en), isEmpty, reason: 'orphaned in app_ml.arb');
  });

  test('no translation is left as the English string', () {
    final en = arb('en');
    final ml = arb('ml');

    // Proper nouns and codes legitimately match across locales; everything else
    // being identical means the key was copied and never translated.
    const allowedIdentical = <String>{};

    final untranslated = keysOf(
      en,
    ).where((key) => en[key] == ml[key] && !allowedIdentical.contains(key)).toList();

    expect(untranslated, isEmpty, reason: 'copied but not translated');
  });

  test('placeholders match between locales', () {
    final en = arb('en');
    final ml = arb('ml');

    // A placeholder is `{name}` or `{name, plural, …}`. The trailing `[,}]`
    // matters: without it the regex also matches the opening of an ICU plural
    // body, so `=1{Offline — …}` reads as a placeholder named "Offline".
    final placeholder = RegExp(r'\{(\w+)\s*[,}]');

    for (final key in keysOf(en)) {
      final inEn = placeholder.allMatches(en[key] as String).map((m) => m.group(1)).toSet();
      final inMl = placeholder.allMatches(ml[key] as String).map((m) => m.group(1)).toSet();

      // A dropped placeholder throws at runtime, in the locale the developer
      // is least likely to be running.
      expect(inMl, inEn, reason: 'placeholder mismatch in "$key"');
    }
  });

  group('mappers', () {
    late L10n en;

    setUpAll(() async {
      en = await L10n.delegate.load(const Locale('en'));
    });

    test('every failure variant maps to copy, none to a code', () {
      final failures = <Failure>[
        const Failure.network(),
        const Failure.timeout(),
        const Failure.unauthorized(),
        const Failure.forbidden('FORBIDDEN_SCOPE'),
        const Failure.validation({}),
        const Failure.conflict(
          ConflictPayload(entity: 'x', entityId: 'y', mine: {}, theirs: {}),
        ),
        const Failure.notFound(),
        const Failure.server('INTERNAL_ERROR'),
        const Failure.unavailableOffline(),
        Failure.unknown(Exception('x'), StackTrace.empty),
      ];

      for (final failure in failures) {
        final message = failure.message(en);
        expect(message, isNotEmpty);
        // The user must never be shown the wire code.
        expect(message, isNot(equals(failure.code)));
      }
    });

    test('every role has a label', () {
      for (final role in AppRole.values) {
        expect(role.label(en), isNotEmpty, reason: role.wire);
        expect(role.label(en), isNot(equals(role.wire)));
      }
    });

    test('every registered screen has a localized nav label', () {
      for (final screen in ScreenRegistry.all) {
        final label = screenLabel(en, screen.id);
        // Falling back to the id means a screen shipped without an ARB entry.
        expect(label, isNot(equals(screen.id)), reason: screen.id);
      }
    });
  });
}
