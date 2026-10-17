/// App settings chosen at build time, never by editing code.
///
/// Demo mode shows the "Simulate card scan" button on the login screen.
/// Turn it off with: flutter run --dart-define=DEMO_MODE=false
class AppConfig {
  AppConfig._();

  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  /// Employee ID the demo "Simulate card scan" button sends (the seed nurse).
  static const demoNurseId = '48216';

  /// Most units of one item in one order. Must match the backend setting
  /// MAX_QTY_PER_ITEM (default 30, docs/api.md); the server rejects more with 422.
  static const maxQtyPerItem = 30;
}
