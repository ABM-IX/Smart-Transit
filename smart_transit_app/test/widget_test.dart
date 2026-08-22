import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_transit_app/main.dart';
import 'package:smart_transit_app/providers/auth_provider.dart';
import 'package:smart_transit_app/providers/transit_provider.dart';

void main() {
  testWidgets('SmartTransit app renders Welcome screen and CTAs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => TransitProvider()),
        ],
        child: const SmartTransitApp(),
      ),
    );

    expect(find.text('SmartTransit'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Combi'), findsOneWidget);
    expect(find.text('Taxi'), findsOneWidget);
  });
}
