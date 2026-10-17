/// App settings chosen at build time, never by editing code.
///
/// Demo mode shows the "Simulate card scan" button on the login screen and, with the
/// mock service, "Simulate robot fault" on the Prepare screen (to show PARTIAL / FAILED).
/// Turn it off with: flutter run --dart-define=DEMO_MODE=false
class AppConfig {
  AppConfig._();

  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  /// Employee ID the demo "Simulate card scan" button sends (the seed nurse).
  static const demoNurseId = '48216';

  /// Most units of one item in one order. Must match the backend setting
  /// MAX_QTY_PER_ITEM (default 30, docs/api.md); the server rejects more with 422.
  static const maxQtyPerItem = 30;

  /// How often the Prepare screen asks GET /orders/{id} for progress (rule: every 1 to 2 s).
  static const pollInterval = Duration(milliseconds: 1500);

  /// Number of slots drawn in the cabinet picture (the seed uses slots 1-6).
  static const cabinetSlots = 6;

  /// Rough seconds the robot needs per unit, for the "About n sec" chip.
  /// 1 matches MockApiService; set it to the real arm's speed later.
  static const estimatedSecondsPerUnit = 1;
}
