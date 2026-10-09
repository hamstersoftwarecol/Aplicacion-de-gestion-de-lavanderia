import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/app.dart';
import 'package:lavanderia/data/laundry_repository.dart';
import '../../support/fake_repository.dart';

class InactiveRepository extends FakeRepository {
  @override
  Future<StaffSession> profile() async => throw const AccessDenied();
}

void main() {
  testWidgets('inactive profile does not see protected data', (tester) async {
    await tester.pumpWidget(LaundryApp(repository: InactiveRepository()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Acceso no disponible'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsNothing);
  });
  testWidgets('responsive navigation renders without overflow', (tester) async {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        LaundryApp(key: UniqueKey(), repository: FakeRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pedidos activos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
