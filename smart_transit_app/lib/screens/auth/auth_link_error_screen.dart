import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../splash/splash_screen.dart';

class AuthLinkErrorScreen extends StatelessWidget {
  const AuthLinkErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.link_off,
                        size: 48,
                        color: AppTheme.accentAmber,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "This link didn't open",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        auth.authLinkError ??
                            'Request a new email and open its link on this phone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            auth.clearAuthLinkError();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const SplashScreen(),
                              ),
                              (_) => false,
                            );
                          },
                          child: const Text('Back to SmartTransit'),
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
