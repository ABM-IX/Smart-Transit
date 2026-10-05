import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/welcome_screen.dart';
import '../driver/driver_dashboard.dart';
import '../passenger/passenger_dashboard.dart';

/// OS-compliant launch animation splash screen for SmartTransit.
///
/// Built with Rive and a state machine:
/// - State 1: Static (0ms, matches native OS launch screen seamlessly)
/// - State 2: TraceAndConnect (0-700ms, S-circuit stroke trim + node pulses)
/// - State 3: Arrival (700-900ms, single location pin arrival pulse)
/// - State 4: Wordmark (900-1100ms, opacity fade of brand title & tagline)
/// - State 5: Idle (1100ms onward, waiting loop with subtle pin breathing)
/// - Boolean input: `appReady` triggering exit once initialization finishes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _assetPath = 'assets/animations/splash.riv';
  static const String _stateMachineName = 'State Machine 1';
  static const String _inputAppReady = 'appReady';
  static const Duration _minRevealDuration = Duration(milliseconds: 1100);
  static const Duration _maxInitTimeout = Duration(milliseconds: 4000);

  late final FileLoader _fileLoader;
  BooleanInput? _appReadyInput;

  bool _isInitFinished = false;
  bool _isMinDurationFinished = false;
  bool _hasNavigated = false;
  Timer? _minDurationTimer;
  Timer? _safetyTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _fileLoader = FileLoader.fromAsset(
      _assetPath,
      riveFactory: Factory.flutter,
    );
    _startTimersAndInit();
  }

  void _startTimersAndInit() {
    // 1. Enforce that reveal states 1-4 complete at least once (~1.1s)
    _minDurationTimer = Timer(_minRevealDuration, () {
      if (mounted) {
        setState(() {
          _isMinDurationFinished = true;
        });
        _checkAndTransition();
      }
    });

    // 2. Safety timeout: never leave user hanging indefinitely on poor network
    _safetyTimeoutTimer = Timer(_maxInitTimeout, () {
      if (mounted && !_hasNavigated) {
        _isInitFinished = true;
        _isMinDurationFinished = true;
        _checkAndTransition();
      }
    });

    // 3. Perform real app startup initialization (auth/session check)
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final authProvider = context.read<AuthProvider>();
      // Give async providers a brief microtask cycle to resolve local cache / session
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      // Check auth status
      if (authProvider.isLoading) {
        int attempts = 0;
        while (authProvider.isLoading && attempts < 15 && mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }
    } catch (_) {
      // Continue gracefully on network or auth errors
    } finally {
      if (mounted) {
        setState(() {
          _isInitFinished = true;
        });
        _checkAndTransition();
      }
    }
  }

  void _onRiveLoaded(RiveLoaded state) {
    try {
      _appReadyInput = state.controller.stateMachine.boolean(_inputAppReady);
    } catch (_) {
      // Safely fallback if input isn't present
    }
    _checkAndTransition();
  }

  void _checkAndTransition() {
    // Only transition when BOTH the minimum reveal animation has finished AND app init is done
    if (_isInitFinished && _isMinDurationFinished && !_hasNavigated) {
      if (_appReadyInput != null) {
        _appReadyInput!.value = true;
        // Allow brief exit transition mix time before navigating
        Future<void>.delayed(const Duration(milliseconds: 150), () {
          if (mounted && !_hasNavigated) {
            _navigateToTarget();
          }
        });
      } else {
        // Fallback if Rive state machine controller wasn't ready
        _navigateToTarget();
      }
    }
  }

  void _navigateToTarget() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    _minDurationTimer?.cancel();
    _safetyTimeoutTimer?.cancel();

    final authProvider = context.read<AuthProvider>();
    final Widget destination;

    if (authProvider.isAuthenticated) {
      destination = authProvider.isDriver
          ? DriverDashboard(initialRole: authProvider.role)
          : const PassengerDashboard();
    } else {
      destination = const WelcomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
              maxHeight: 560,
            ),
            child: RiveWidgetBuilder(
              fileLoader: _fileLoader,
              stateMachineSelector: const StateMachineNamed(_stateMachineName),
              onLoaded: _onRiveLoaded,
              builder: (context, state) {
                if (state is RiveLoaded) {
                  return RiveWidget(
                    controller: state.controller,
                    fit: Fit.contain,
                  );
                }
                return const Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
