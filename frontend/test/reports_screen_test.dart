import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/file_saver.dart';
import 'package:id_nurse/services/mock_api_service.dart';
import 'package:intl/intl.dart';

/// A FileSaver that keeps the files in memory, so tests can read what was "saved".
class _FakeSaver implements FileSaver {
  final saved = <String, String>{};
  bool fail = false;

  @override
  String get folderName => 'Downloads';

  @override
  Future<String> save(String fileName, String content) async {
    if (fail) throw const FileSystemLikeError();
    saved[fileName] = content;
    return 'C:\\Users\\demo\\Downloads\\$fileName';
  }
}

class FileSystemLikeError implements Exception {
  const FileSystemLikeError();
}

/// Supervisor dashboard "Reports": the CSV export.
void main() {
  late MockApiService api;
  late _FakeSaver saver;

  final fileName = 'dispense-report-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

  setUp(() {
    api = MockApiService(networkDelay: Duration.zero, pickInterval: const Duration(milliseconds: 5));
    saver = _FakeSaver();
  });

  tearDown(() => api.dispose());

  /// Order #1 by the nurse (2 lines, DONE) and order #2 by the supervisor (PENDING).
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      await api.login('48216', LoginMethod.scan);
      final order = await api.createOrder('284913', const [
        OrderLineRequest(itemId: 1, qty: 2),
        OrderLineRequest(itemId: 5, qty: 1),
      ]);
      await api.approveOrder(order.id);
      while (!(await api.getOrder(order.id)).status.isFinal) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);
      await api.createOrder('548220', const [OrderLineRequest(itemId: 2, qty: 1)]);
      api.signOut();
    });
  }

  Future<void> openReports(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api, fileSaver: saver));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('supervisor-id')), '31082');
    await tester.enterText(find.byKey(const Key('supervisor-password')), MockApiService.demoSupervisorPassword);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/reports')));
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('export-csv')));
    await tester.pumpAndSettle();
  }

  String resultText(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: find.byKey(const Key('export-result')), matching: find.byType(Text)))
      .data!;

  testWidgets('Export CSV saves the dispense report and says where', (tester) async {
    await seed(tester);
    await openReports(tester);
    expect(find.text('Dispense report (CSV)'), findsOneWidget);
    await export(tester);

    expect(resultText(tester), 'Saved $fileName to Downloads (3 rows).');
    final csv = saver.saved[fileName]!;
    expect(csv, startsWith('order_id,created_at,completed_at,status,'));
    expect(csv, contains('"Nitrile gloves, M"'));
    expect(csv.trimRight().split('\n'), hasLength(4)); // header + 3 lines
    expect(csv, isNot(contains('CANCELLED')));
  });

  testWidgets('the nurse filter is applied to the export', (tester) async {
    await seed(tester);
    await openReports(tester);
    await tester.tap(find.byKey(const Key('filter-nurse')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maya Chen').last);
    await tester.pumpAndSettle();
    await export(tester);
    expect(resultText(tester), 'Saved $fileName to Downloads (2 rows).');
    expect(saver.saved[fileName], isNot(contains('Elena Ruiz')));
  });

  testWidgets('nothing to export: a warning and no file', (tester) async {
    await openReports(tester); // no orders at all
    await export(tester);
    expect(resultText(tester), 'No orders match these filters. Nothing was saved.');
    expect(saver.saved, isEmpty);
  });

  testWidgets('a save error is shown', (tester) async {
    await seed(tester);
    saver.fail = true;
    await openReports(tester);
    await export(tester);
    expect(resultText(tester), 'Could not save the report. Try again.');
  });

  testWidgets('changing a filter clears the old message', (tester) async {
    await seed(tester);
    await openReports(tester);
    await export(tester);
    expect(find.byKey(const Key('export-result')), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-nurse')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maya Chen').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-result')), findsNothing);
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets(label, (tester) async {
        await seed(tester);
        await openReports(tester, size: size);
        await export(tester);
        expect(find.byType(SingleChildScrollView), findsNothing);
        final card = tester.getRect(find.byKey(const Key('admin-card')));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(find.byKey(const Key('export-result'))).bottom, lessThanOrEqualTo(card.bottom));
      });
    }
  });
}
