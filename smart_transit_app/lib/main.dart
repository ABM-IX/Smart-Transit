import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/transit_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/email_verified_screen.dart';
import 'screens/auth/auth_link_error_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth_deep_link_service.dart';

final AuthDeepLinkService _authDeepLinkService = AuthDeepLinkService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );

  final authProvider = AuthProvider();
  Uri? initialAuthLink;
  try {
    initialAuthLink = await _authDeepLinkService.getInitialLink();
  } catch (error) {
    authProvider.reportAuthLinkError(error);
  }
  if (_authDeepLinkService.isPasswordRecoveryLink(initialAuthLink)) {
    // Choose the recovery screen before the first frame so sign-in does not
    // appear while Android's initial-link callback is being delivered.
    authProvider.beginPasswordRecovery();
  }
  _authDeepLinkService.start(
    onError: authProvider.reportAuthLinkError,
    onPasswordRecovery: authProvider.beginPasswordRecovery,
    initialLink: initialAuthLink,
  );
  final themeProvider = AppThemeProvider();
  await themeProvider.loadPreference();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => TransitProvider()),
      ],
      child: const SmartTransitApp(),
    ),
  );
}

class SmartTransitApp extends StatelessWidget {
  const SmartTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeProvider>(
      builder: (context, appTheme, _) => Consumer<AuthProvider>(
        builder: (context, auth, _) => MaterialApp(
          title: 'SmartTransit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appTheme.themeMode,
          home: auth.passwordRecoveryPending
              ? const ResetPasswordScreen()
              : auth.authLinkError != null
              ? const AuthLinkErrorScreen()
              : auth.emailVerifiedWelcomePending
              ? const EmailVerifiedScreen()
              : const SplashScreen(),
        ),
      ),
    );
  }
}
