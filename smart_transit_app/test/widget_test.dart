import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_transit_app/main.dart';
import 'package:smart_transit_app/providers/auth_provider.dart';
import 'package:smart_transit_app/providers/transit_provider.dart';
import 'package:smart_transit_app/providers/theme_provider.dart';
import 'package:smart_transit_app/screens/splash/splash_screen.dart';

void main() {
  testWidgets('SmartTransit app renders Welcome screen and CTAs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => TransitProvider()),
          ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ],
        child: const SmartTransitApp(),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
