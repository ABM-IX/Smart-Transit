import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../splash/splash_screen.dart';

class EmailVerifiedScreen extends StatefulWidget {
  const EmailVerifiedScreen({super.key});

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  Future<void> _continueToSignIn() async {
    context.read<AuthProvider>().finishEmailVerifiedWelcome();
    try {
      await AuthService().signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 54,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome to SmartTransit!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your email is verified and your account is ready. Sign in to start planning trips and finding rides.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _continueToSignIn,
                          child: const Text('Continue to sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
