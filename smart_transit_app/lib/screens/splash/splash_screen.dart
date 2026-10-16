import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../auth/login_screen.dart';
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
  static const String _lightAssetPath = 'assets/animations/splash.riv';
  static const String _darkAssetPath = 'assets/animations/splash_dark.riv';
  static const String _stateMachineName = 'State Machine 1';
  static const String _inputAppReady = 'appReady';
  static const Duration _minRevealDuration = Duration(milliseconds: 2600);
  static const Duration _maxInitTimeout = Duration(milliseconds: 4000);

  late FileLoader _fileLoader;
  final List<FileLoader> _fileLoaders = [];
  Brightness? _riveBrightness;
  bool _reduceMotion = false;
  BooleanInput? _appReadyInput;

  bool _isInitFinished = false;
  bool _isMinDurationFinished = false;
  bool _hasNavigated = false;
  Timer? _minDurationTimer;
  Timer? _safetyTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _startTimersAndInit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final brightness = Theme.of(context).brightness;
    if (_riveBrightness != brightness) {
      _riveBrightness = brightness;
      _appReadyInput = null;
      _fileLoader = FileLoader.fromAsset(
        brightness == Brightness.dark ? _darkAssetPath : _lightAssetPath,
        riveFactory: Factory.flutter,
      );
      _fileLoaders.add(_fileLoader);
    }
  }

  void _startTimersAndInit() {
    // 1. Enforce that reveal states 1-4 complete at least once (~1.1s)
    _minDurationTimer = Timer(
      _reduceMotion ? Duration.zero : _minRevealDuration,
      () {
        if (mounted) {
          setState(() {
            _isMinDurationFinished = true;
          });
          _checkAndTransition();
        }
      },
    );

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
      // Let the logo animate while cached session data loads in the background.
      while (!authProvider.isSessionReady && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (!mounted) return;
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
      if (_appReadyInput != null && !_reduceMotion) {
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
    for (final loader in _fileLoaders) {
      loader.dispose();
    }

    final authProvider = context.read<AuthProvider>();
    final Widget destination;

    if (authProvider.isAuthenticated) {
      final transit = context.read<TransitProvider>();
      transit.fetchInitialData();
      if (authProvider.isDriver) {
        transit.connectSocket(
          role: 'drivers',
          userId: authProvider.userId,
          routeId: authProvider.role == UserRole.driverTaxi
              ? 'taxi-service'
              : authProvider.assignedRouteId,
        );
      } else {
        transit.connectSocket(role: 'passengers', userId: authProvider.userId);
      }

      destination = authProvider.isDriver
          ? DriverDashboard(initialRole: authProvider.role)
          : const PassengerDashboard();
    } else {
      destination = const LoginScreen();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: RiveWidgetBuilder(
              key: ValueKey(_riveBrightness),
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
                return Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
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
