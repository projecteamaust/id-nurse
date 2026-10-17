import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/models/item.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// Supervisor dashboard "Stock": the item table and "Edit quantity".
void main() {
  late MockApiService api;

  tearDown(() => api.dispose());

  /// Signs in as the supervisor and opens Stock.
  Future<void> openStock(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('supervisor-id')), '31082');
    await tester.enterText(find.byKey(const Key('supervisor-password')), MockApiService.demoSupervisorPassword);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/stock')));
    await tester.pumpAndSettle();
  }

  Finder inTable(Finder finder) => find.descendant(of: find.byKey(const Key('stock-table')), matching: finder);

  /// The text in the Quantity column of an item.
  String qty(WidgetTester tester, int itemId) => tester.widget<Text>(find.byKey(ValueKey('qty-$itemId'))).data!;

  /// The status chip text in an item's row.
  Finder rowChip(int itemId, String label) => find.descendant(
        of: find.ancestor(of: find.byKey(ValueKey('qty-$itemId')), matching: find.byType(Row)).first,
        matching: find.text(label),
      );

  Future<void> openEdit(WidgetTester tester, int itemId) async {
    await tester.tap(find.byKey(ValueKey('edit-$itemId')));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));

  testWidgets('lists every item with slot, category, quantity, minimum and status', (tester) async {
    api = MockApiService(networkDelay: Duration.zero);
    await openStock(tester);
    for (final header in ['SLOT', 'ITEM', 'CATEGORY', 'QUANTITY', 'MINIMUM', 'STATUS']) {
      expect(find.text(header), findsOneWidget);
    }
    for (final name in [
      'Sterile gauze pads',
      'Adhesive dressing',
      'IV administration set',
      '10 ml syringe',
      'Nitrile gloves, M',
      'Procedure mask',
    ]) {
      expect(inTable(find.text(name)), findsOneWidget, reason: name);
    }
    expect(inTable(find.text('Wound care')), findsNWidgets(2));
    expect(qty(tester, 1), '42');
    expect(rowChip(1, 'In stock'), findsOneWidget);
    expect(qty(tester, 2), '9'); // minimum 10
    expect(rowChip(2, 'Low'), findsOneWidget);
    expect(qty(tester, 4), '0');
    expect(rowChip(4, 'Empty'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Edit quantity'), findsNWidgets(6));
  });

  testWidgets('edit a quantity: the row and the chip update, and a message is shown', (tester) async {
    api = MockApiService(networkDelay: Duration.zero);
    await openStock(tester);
    await openEdit(tester, 1);
    expect(find.text('Edit stock · Sterile gauze pads'), findsOneWidget);
    expect(find.text('Slot 1 · now 42 units · minimum 10'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('stock-quantity')), '5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit stock · Sterile gauze pads'), findsNothing);
    expect(qty(tester, 1), '5');
    expect(rowChip(1, 'Low'), findsOneWidget);
    expect(find.text('Stock updated: Sterile gauze pads, 5 units.'), findsOneWidget);
    expect((await tester.runAsync(() => api.getItems(search: 'gauze')))!.single.quantity, 5);
  });

  testWidgets('Save is off while the field is empty or unchanged; only 3 digits can be typed', (tester) async {
    api = MockApiService(networkDelay: Duration.zero);
    await openStock(tester);
    await openEdit(tester, 2);
    expect(saveButton(tester).onPressed, isNull); // still 9

    await tester.enterText(find.byKey(const Key('stock-quantity')), '');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('stock-quantity')), '12ab3456');
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('stock-quantity'))).controller!.text, '123');
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(qty(tester, 2), '9'); // nothing saved
  });

  testWidgets('an error from the server is shown inside the dialog', (tester) async {
    api = _FailingStockApi();
    await openStock(tester);
    await openEdit(tester, 1);
    await tester.enterText(find.byKey(const Key('stock-quantity')), '7');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Server error'), findsOneWidget);
    expect(find.text('Edit stock · Sterile gauze pads'), findsOneWidget); // still open
    expect(saveButton(tester).onPressed, isNotNull); // can try again
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets(label, (tester) async {
        api = MockApiService(networkDelay: Duration.zero);
        await openStock(tester, size: size);
        expect(find.byType(SingleChildScrollView), findsNothing);
        final card = tester.getRect(find.byKey(const Key('admin-card')));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(find.byKey(const Key('stock-table'))).bottom, lessThanOrEqualTo(card.bottom));
        // All 6 items are visible: the table does not need to scroll.
        final body = find.descendant(of: find.byKey(const Key('stock-table')), matching: find.byType(Scrollable));
        expect(tester.state<ScrollableState>(body.first).position.maxScrollExtent, 0);

        await openEdit(tester, 1);
        expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}

/// The mock, but saving a quantity fails like a server error.
class _FailingStockApi extends MockApiService {
  _FailingStockApi() : super(networkDelay: Duration.zero);

  @override
  Future<Item> updateItemQuantity(int itemId, int quantity) async => throw const ApiException(500, 'Server error');
}
