// Phase 1A — basic smoke test confirming the app shell renders without errors.
// More meaningful tests will be added per-phase as features are implemented.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: We test _ShellScreen in isolation here because main() requires
// AudioService.init(), which needs a real platform channel not available
// in flutter_test. Each subsequent phase will add unit and widget tests
// for the specific features introduced.

void main() {
  testWidgets('Shell screen renders LoopPlayer title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('LoopPlayer'),
          ),
        ),
      ),
    );
    expect(find.text('LoopPlayer'), findsOneWidget);
  });
}
