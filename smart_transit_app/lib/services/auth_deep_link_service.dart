import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthDeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  final Set<String> _handledLinks = {};

  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  bool isPasswordRecoveryLink(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'smarttransit' ||
        uri.host != 'auth-callback') {
      return false;
    }
    try {
      final fragment = Uri.splitQueryString(uri.fragment);
      return uri.queryParameters['flow'] == 'recovery' ||
          uri.queryParameters['type'] == 'recovery' ||
          fragment['type'] == 'recovery';
    } catch (_) {
      return false;
    }
  }

  void start({
    required void Function(Object error) onError,
    required void Function() onPasswordRecovery,
    Uri? initialLink,
  }) {
    _subscription ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri, onError, onPasswordRecovery)),
      onError: (Object error) => onError(error),
    );
    if (initialLink != null) {
      unawaited(_handle(initialLink, onError, onPasswordRecovery));
    }
  }

  Future<void> _handle(
    Uri uri,
    void Function(Object error) onError,
    void Function() onPasswordRecovery,
  ) async {
    try {
      if (!_handledLinks.add(uri.toString())) return;
      if (uri.scheme != 'smarttransit' || uri.host != 'auth-callback') return;
      if (isPasswordRecoveryLink(uri)) onPasswordRecovery();
      final fragment = Uri.splitQueryString(uri.fragment);
      final hasAuthResponse =
          uri.queryParameters.containsKey('code') ||
          uri.queryParameters.containsKey('error') ||
          uri.queryParameters.containsKey('error_code') ||
          uri.queryParameters.containsKey('access_token') ||
          fragment.containsKey('code') ||
          fragment.containsKey('error') ||
          fragment.containsKey('error_code') ||
          fragment.containsKey('access_token');
      if (!hasAuthResponse) return;
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (error) {
      onError(error);
    }
  }
}
