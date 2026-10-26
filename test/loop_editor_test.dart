import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/data/models/loop_profile.dart';
import 'package:loop_player/data/repositories/loop_profile_repository.dart';
import 'package:loop_player/domain/loop/loop_mode.dart';
import 'package:loop_player/domain/waveform/waveform_loader.dart';
import 'package:loop_player/domain/waveform/waveform_peaks.dart';
import 'package:loop_player/presentation/now_playing/waveform_view.dart';
import 'package:loop_player/providers/waveform_provider.dart';
import 'package:loop_player/presentation/now_playing/loop_editor_sheet.dart';
import 'package:loop_player/providers/audio_handler_provider.dart';
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

/// Stand-in for the waveform generator. Fails when [fail] is true.
class _FakeLoader implements WaveformLoader {
  _FakeLoader({this.fail = false});
  bool fail;
  int loadCalls = 0;

  @override
  Future<WaveformPeaks> load(String songId,
      {void Function(double progress)? onProgress}) async {
    loadCalls++;
    if (fail) throw WaveformException("Couldn't read this audio file.");
    return WaveformPeaks(
      values: List<double>.generate(600, (i) => (i % 50) / 50),
      peaksPerSecond: 10,
    );
  }
}

/// Stand-in for the player's Preview. Records what the editor asked for.
class _FakePreview {
  _FakePreview({this.canStart = true});
  bool canStart;
  final List<List<Object>> starts = [];
  int stops = 0;
  bool? lastStopPause;
}

Widget _app(
  _FakeRepo repo, {
  _FakeLoader? loader,
  _FakePreview? preview,
  bool previewing = false,
}) {
  final fake = preview ?? _FakePreview();
  return ProviderScope(
      overrides: [
        loopProfileRepositoryProvider.overrideWithValue(repo),
        // No real player in tests: applying a loop does nothing here.
        loopProfileApplierProvider.overrideWithValue((profile) async {}),
        waveformLoaderProvider.overrideWithValue(loader ?? _FakeLoader()),
        positionProvider.overrideWith((ref) => const Stream<Duration>.empty()),
        loopPreviewStartProvider.overrideWithValue(({
          required String songId,
          required int startMs,
          required int endMs,
        }) async {
          fake.starts.add([songId, startMs, endMs]);
          return fake.canStart;
        }),
        loopPreviewStopProvider.overrideWithValue(({bool pause = true}) {
          fake.stops++;
          fake.lastStopPause = pause;
        }),
        loopPreviewingProvider.overrideWith((ref) => Stream<bool>.value(previewing)),
      ],
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
}

/// Text currently in a time field. (find.text would also match the waveform's
/// handle labels, which show the same times.)
String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> _open(WidgetTester tester) async {
  // A taller screen (800 x 1000 logical px) so the whole editor is visible.
  tester.view.physicalSize = const Size(2400, 3000);
  addTearDown(tester.view.reset);
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

    expect(_field(tester, 'loop_start_field'), '0:10');
    expect(_field(tester, 'loop_end_field'), '0:20');
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
  testWidgets('shows the waveform once it is ready', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo()));
    await _open(tester);

    expect(find.byType(WaveformView), findsOneWidget);
    expect(find.byKey(const Key('waveform_error')), findsNothing);
  });

  testWidgets('a failed waveform shows a message, Retry, and saving still works',
      (tester) async {
    final repo = _FakeRepo();
    final loader = _FakeLoader(fail: true);
    await tester.pumpWidget(_app(repo, loader: loader));
    await _open(tester);

    expect(find.byKey(const Key('waveform_error')), findsOneWidget);
    expect(find.textContaining("Couldn't read this audio file."), findsOneWidget);
    expect(find.byType(WaveformView), findsNothing);

    // The form still works without a waveform.
    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:10');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:20');
    await tester.tap(find.text('Infinite'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_save_button')));
    await tester.pumpAndSettle();
    expect(repo.saveCalls, 1);
  });

  testWidgets('Retry loads the waveform again', (tester) async {
    final loader = _FakeLoader(fail: true);
    await tester.pumpWidget(_app(_FakeRepo(), loader: loader));
    await _open(tester);
    expect(loader.loadCalls, 1);

    loader.fail = false;
    await tester.tap(find.byKey(const Key('waveform_retry')));
    await tester.pumpAndSettle();

    expect(loader.loadCalls, 2);
    expect(find.byType(WaveformView), findsOneWidget);
  });

  testWidgets('+/- buttons move a handle by 0.1 s and leave the other alone',
      (tester) async {
    await tester.pumpWidget(_app(_FakeRepo()));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:10');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:20');
    await tester.tap(find.text('Infinite'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('loop_start_plus')));
    await tester.pump();
    expect(_field(tester, 'loop_start_field'), '0:10.1');
    expect(_field(tester, 'loop_end_field'), '0:20');

    await tester.tap(find.byKey(const Key('loop_end_minus')));
    await tester.pump();
    expect(_field(tester, 'loop_start_field'), '0:10.1');
    expect(_field(tester, 'loop_end_field'), '0:19.9');
  });

  testWidgets('the handles cannot cross: End stops 0.1 s after Start',
      (tester) async {
    await tester.pumpWidget(_app(_FakeRepo()));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:10');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:10.2');
    await tester.tap(find.text('Infinite'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('loop_end_minus')));
    await tester.pump();
    expect(_field(tester, 'loop_end_field'), '0:10.1');

    await tester.tap(find.byKey(const Key('loop_end_minus')));
    await tester.pump();
    expect(_field(tester, 'loop_end_field'), '0:10.1'); // no further
    expect(_field(tester, 'loop_start_field'), '0:10'); // Start unchanged
  });

  testWidgets('End cannot be nudged past the end of the song', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo()));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:59.95');
    await tester.tap(find.byKey(const Key('loop_end_plus')));
    await tester.pump();
    expect(_field(tester, 'loop_end_field'), '1:00');

    await tester.tap(find.byKey(const Key('loop_end_plus')));
    await tester.pump();
    expect(_field(tester, 'loop_end_field'), '1:00');
  });

  testWidgets('a nudge with unreadable text shows a message', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo()));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), 'abc');
    await tester.tap(find.byKey(const Key('loop_start_plus')));
    await tester.pump();
    expect(find.text('Enter times like 1:05 or 65.'), findsOneWidget);
  });

  testWidgets('nudged values are what gets saved', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:10');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:20');
    await tester.tap(find.text('Infinite'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_start_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('loop_save_button')));
    await tester.pumpAndSettle();

    expect(repo.saved['s1']!.loopStartMs, 10100);
    expect(repo.saved['s1']!.loopEndMs, 20000);
  });

  testWidgets('Preview plays the unsaved fields, without saving anything',
      (tester) async {
    final repo = _FakeRepo();
    final preview = _FakePreview();
    await tester.pumpWidget(_app(repo, preview: preview));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:10');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:20');
    await tester.tap(find.byKey(const Key('loop_preview_button')));
    await tester.pumpAndSettle();

    expect(preview.starts, [
      ['s1', 10000, 20000]
    ]);
    expect(repo.saveCalls, 0);
    expect(find.byType(LoopEditorSheet), findsOneWidget);
  });

  testWidgets('Preview with an invalid range shows a message and does not play',
      (tester) async {
    final preview = _FakePreview();
    await tester.pumpWidget(_app(_FakeRepo(), preview: preview));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_start_field')), '0:30');
    await tester.enterText(find.byKey(const Key('loop_end_field')), '0:10');
    await tester.tap(find.byKey(const Key('loop_preview_button')));
    await tester.pumpAndSettle();

    expect(find.text('Loop start must be before loop end.'), findsOneWidget);
    expect(preview.starts, isEmpty);
  });

  testWidgets('Preview with unreadable text shows a message', (tester) async {
    final preview = _FakePreview();
    await tester.pumpWidget(_app(_FakeRepo(), preview: preview));
    await _open(tester);

    await tester.enterText(find.byKey(const Key('loop_end_field')), 'abc');
    await tester.tap(find.byKey(const Key('loop_preview_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter times like 1:05 or 65.'), findsOneWidget);
    expect(preview.starts, isEmpty);
  });

  testWidgets('if the song is not the playing one, Preview explains why',
      (tester) async {
    final preview = _FakePreview(canStart: false);
    await tester.pumpWidget(_app(_FakeRepo(), preview: preview));
    await _open(tester);

    await tester.tap(find.byKey(const Key('loop_preview_button')));
    await tester.pumpAndSettle();

    expect(preview.starts.length, 1);
    expect(find.textContaining('Preview only works'), findsOneWidget);
  });

  testWidgets('while previewing the button says Stop and pressing it stops',
      (tester) async {
    final preview = _FakePreview();
    await tester.pumpWidget(_app(_FakeRepo(), preview: preview, previewing: true));
    await _open(tester);

    expect(find.text('Stop preview'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loop_preview_button')));
    await tester.pumpAndSettle();

    expect(preview.stops, 1);
    expect(preview.lastStopPause, isTrue);
    expect(preview.starts, isEmpty);
  });

  testWidgets('closing the editor ends the preview but does not pause',
      (tester) async {
    final preview = _FakePreview();
    await tester.pumpWidget(_app(_FakeRepo(), preview: preview));
    await _open(tester);

    await tester.tap(find.byKey(const Key('loop_cancel_button')));
    await tester.pumpAndSettle();

    expect(preview.stops, 1);
    expect(preview.lastStopPause, isFalse);
  });
}
