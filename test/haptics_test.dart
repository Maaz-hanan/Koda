import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_player/core/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('tick, light and medium send the right iPhone haptic', () async {
    final sent = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        sent.add(call.arguments as String);
      }
      return null;
    });

    Haptics.tick();
    Haptics.light();
    Haptics.medium();
    await pumpEventQueue();

    expect(sent, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  test('a failing haptic never throws and never crashes the app', () async {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      throw PlatformException(code: 'no-haptics');
    });

    Haptics.tick();
    Haptics.light();
    Haptics.medium();
    await pumpEventQueue();
    // Reaching this line without an uncaught error is the test.
    expect(true, isTrue);
  });
}
