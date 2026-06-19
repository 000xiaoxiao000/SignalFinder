import 'package:flutter_test/flutter_test.dart';
import 'package:netboost/main.dart';
import 'package:netboost/providers/network_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows the main navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NetworkProvider(),
        child: const NetBoostApp(),
      ),
    );

    expect(find.text('实时监测'), findsOneWidget);
    expect(find.text('找信号'), findsOneWidget);
    expect(find.text('DNS 优选'), findsOneWidget);
    expect(find.text('网络诊断'), findsOneWidget);
    expect(find.text('二维码'), findsOneWidget);
  });
}
