// App smoke test. (Replaces the default Flutter "counter" template test,
// which tested a counter widget that does not exist in this app.)

import 'package:app/features/splash/presentation/splash_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('app launches on the splash screen', (tester) async {
    setUpFakes();
    await pumpApp(tester);

    expect(find.byType(SplashView), findsOneWidget);
    expect(find.text('ECO CONNECT'), findsOneWidget);

    // Let the splash redirect timer complete so no timers are left pending.
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
