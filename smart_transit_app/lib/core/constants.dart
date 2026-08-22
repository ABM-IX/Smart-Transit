class AppConstants {
  // Live Production Cloud Backend URL (Render.com)
  static const String cloudServerUrl = 'https://smart-transit-uhyf.onrender.com';
  
  // Local network LAN IP fallback
  static const String lanServerUrl = 'http://10.189.239.26:8000';
  
  // Emulator & localhost fallbacks
  static const String emulatorServerUrl = 'http://10.0.2.2:8000';
  static const String localhostUrl = 'http://127.0.0.1:8000';

  // Active Server URL currently in use by the app (Defaults to live cloud server)
  static String customServerUrl = '';
  static String get defaultServerUrl {
    if (customServerUrl.isNotEmpty) return customServerUrl;
    return cloudServerUrl;
  }


  // Default initial coordinates (Centered on Botswana)
  static const double defaultLatitude = -24.6546;
  static const double defaultLongitude = 25.9145;
  static const double defaultZoom = 14.5;

  // Transit Modes
  static const String modeCombi = 'COMBI';
  static const String modeTaxi = 'TAXI';
  static const String modeBus = 'BUS';

  // Fares
  static const double standardFareBWP = 8.0;

  // Supabase Configuration
  static const String supabaseUrl = 'https://xpphmiajwjkcxtxitcex.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_7cqahorS_JAw4601eqpQkA_xPgA3YZL';
  static const String supabaseAnonKey = supabasePublishableKey;
}

