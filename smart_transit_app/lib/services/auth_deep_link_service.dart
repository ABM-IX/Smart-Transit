import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthDeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  final Set<String> _handledLinks = {};

  void start({
    required void Function(Object error) onError,
    required void Function() onPasswordRecovery,
  }) {
    _subscription ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri, onError, onPasswordRecovery)),
      onError: (Object error) => onError(error),
    );
    unawaited(
      _appLinks
          .getInitialLink()
          .then((uri) {
            if (uri != null) {
              unawaited(_handle(uri, onError, onPasswordRecovery));
            }
          })
          .catchError((Object error) => onError(error)),
    );
  }

  Future<void> _handle(
    Uri uri,
    void Function(Object error) onError,
    void Function() onPasswordRecovery,
  ) async {
    try {
      if (!_handledLinks.add(uri.toString())) return;
      if (uri.scheme != 'smarttransit' || uri.host != 'auth-callback') return;
      final fragment = Uri.splitQueryString(uri.fragment);
      final isRecovery =
          uri.queryParameters['flow'] == 'recovery' ||
          uri.queryParameters['type'] == 'recovery' ||
          fragment['type'] == 'recovery';
      if (isRecovery) onPasswordRecovery();
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
