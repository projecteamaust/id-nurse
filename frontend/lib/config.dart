/// App settings chosen at build time, never by editing code.
///
/// Demo mode shows the "Simulate card scan" button on the login screen.
/// Turn it off with: flutter run --dart-define=DEMO_MODE=false
class AppConfig {
  AppConfig._();

  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  /// Employee ID the demo "Simulate card scan" button sends (the seed nurse).
  static const demoNurseId = '48216';
}
