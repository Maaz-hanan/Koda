import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/loop_profile.dart';
import 'package:loop_player/data/repositories/loop_profile_repository.dart';
import 'package:loop_player/domain/loop/loop_mode.dart';
import 'package:loop_player/presentation/now_playing/loop_editor_sheet.dart';
import 'package:loop_player/providers/repository_providers.dart';

/// In-memory stand-in for the database.
class _FakeRepo implements LoopProfileRepository {
  final Map<String, LoopProfile> saved = {};
  int saveCalls = 0;

  @override
  Future<LoopProfile?> findProfile(String songId) async => saved[songId];

  @override
  Future<LoopProfile> getProfile(String songId) async =>
      saved[songId] ?? LoopProfile.defaultFor(songId);

  @override
  Future<void> saveProfile(LoopProfile profile) async {
    saveCalls++;
    saved[profile.songId] = profile;
  }

  @override
  Future<void> deleteProfile(String songId) async => saved.remove(songId);
}

Widget _app(_FakeRepo repo) => ProviderScope(
      overrides: [loopProfileRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: LoopEditorSheet(songId: 's1', durationMs: 60000),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening pre-fills the saved profile', (tester) async {
    final repo = _FakeRepo()
      ..saved['s1'] = const LoopProfile(
        songId: 's1',
        mode: LoopMode.infiniteSection,
        loopStartMs: 10000,
        loopEndMs: 20000,
        updatedAt: 0,
      );
    await tester.pumpWidget(_app(repo));
    await _open(tester);

    expect(find.text('0:10'), findsOneWidget);
    expect(find.text('0:20'), findsOneWidget);
  });

  testWidgets('saving a valid loop writes it and closes', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:10');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:20');
    await tester.tap(find.text('Infinite'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_save_button')));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, 1);
    final p = repo.saved['s1']!;
    expect(p.mode, LoopMode.infiniteSection);
    expect(p.loopStartMs, 10000);
    expect(p.loopEndMs, 20000);
    expect(find.byType(LoopEditorSheet), findsNothing);
  });

  testWidgets('start after end is rejected with a message', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:30');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:10');
    await tester.tap(find.text('Infinite'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Loop start must be before loop end.'), findsOneWidget);
    expect(repo.saveCalls, 0);
    expect(find.byType(LoopEditorSheet), findsOneWidget);
  });

  testWidgets('unreadable time is rejected', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), 'abc');
    await tester.tap(find.text('Infinite'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter times like 1:05 or 65.'), findsOneWidget);
    expect(repo.saveCalls, 0);
  });

  testWidgets('cancel closes without saving anything', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:05');
    await tester.tap(find.text('Infinite'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_cancel_button')));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, 0);
    expect(repo.saved, isEmpty);
    expect(find.byType(LoopEditorSheet), findsNothing);
  });
}
