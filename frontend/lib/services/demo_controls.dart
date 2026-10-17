/// Extra actions for the demo, offered only by fake services (MockApiService).
/// Kept apart from [ApiService] so the real API never needs a fake-fault endpoint:
/// screens check `api is DemoControls`, so these buttons vanish with RealApiService.
abstract class DemoControls {
  /// From now on every pick in this order fails, like a real arm fault.
  /// The robot retries once, then the order ends as PARTIAL (something was picked)
  /// or FAILED (nothing was picked), as in docs/order-flow-and-arm.md.
  void simulateArmFault(int orderId);
}
