import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/domain/loop/loop_mode.dart';
import 'package:loop_player/domain/loop/whole_song_repeat.dart';

void main() {
  group('nextRepeatMode (tap cycle)', () {
    test('Off -> Once -> Infinite -> Off', () {
      expect(nextRepeatMode(LoopMode.off), LoopMode.repeatOnce);
      expect(nextRepeatMode(LoopMode.repeatOnce), LoopMode.repeatInfinite);
      expect(nextRepeatMode(LoopMode.repeatInfinite), LoopMode.off);
    });

    test('a section loop goes to Off on tap', () {
      expect(nextRepeatMode(LoopMode.finiteSection), LoopMode.off);
      expect(nextRepeatMode(LoopMode.infiniteSection), LoopMode.off);
    });
  });

  group('WholeSongRepeat', () {
    test('Off: song end advances', () {
      final r = WholeSongRepeat();
      expect(r.onSongCompleted(), CompletionAction.advance);
      expect(r.mode, LoopMode.off);
    });

    test('Once: exactly ONE extra play, then Off and advance', () {
      final r = WholeSongRepeat()..setMode(LoopMode.repeatOnce);
      // First time the song ends -> replay, mode stays highlighted.
      expect(r.onSongCompleted(), CompletionAction.replay);
      expect(r.mode, LoopMode.repeatOnce);
      // The replay ends -> advance, mode returns to Off.
      expect(r.onSongCompleted(), CompletionAction.advance);
      expect(r.mode, LoopMode.off);
      // And it does not replay again.
      expect(r.onSongCompleted(), CompletionAction.advance);
    });

    test('Infinite: replays 25 times in a row and stays Infinite', () {
      final r = WholeSongRepeat()..setMode(LoopMode.repeatInfinite);
      for (var i = 0; i < 25; i++) {
        expect(r.onSongCompleted(), CompletionAction.replay);
      }
      expect(r.mode, LoopMode.repeatInfinite);
    });

    test('changing mode during the extra play restarts Once cleanly', () {
      final r = WholeSongRepeat()..setMode(LoopMode.repeatOnce);
      expect(r.onSongCompleted(), CompletionAction.replay); // extra play begins
      r.cycle(); // Once -> Infinite
      r.cycle(); // Infinite -> Off
      r.cycle(); // Off -> Once (fresh)
      expect(r.mode, LoopMode.repeatOnce);
      expect(r.onSongCompleted(), CompletionAction.replay); // a full extra play again
      expect(r.onSongCompleted(), CompletionAction.advance);
    });

    test('Next / track change exits Infinite and Once', () {
      final r = WholeSongRepeat()..setMode(LoopMode.repeatInfinite);
      r.onTrackChange();
      expect(r.mode, LoopMode.off);
      expect(r.onSongCompleted(), CompletionAction.advance);

      r.setMode(LoopMode.repeatOnce);
      r.onSongCompleted(); // extra play running
      r.onTrackChange();
      expect(r.mode, LoopMode.off);
    });

    test('cycle() walks Off -> Once -> Infinite -> Off', () {
      final r = WholeSongRepeat();
      expect([r.cycle(), r.cycle(), r.cycle()], [
        LoopMode.repeatOnce,
        LoopMode.repeatInfinite,
        LoopMode.off,
      ]);
    });
  });
}
