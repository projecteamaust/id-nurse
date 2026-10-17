import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/services/file_saver.dart';

/// DownloadsFileSaver, in a temporary folder instead of the real Downloads.
void main() {
  late Directory folder;
  late DownloadsFileSaver saver;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('id_nurse_saver_');
    saver = DownloadsFileSaver(directory: folder);
  });

  tearDown(() => folder.deleteSync(recursive: true));

  test('writes the file and returns its full path', () async {
    final path = await saver.save('report.csv', 'a,b\n1,2\n');
    expect(path, '${folder.path}${Platform.pathSeparator}report.csv');
    expect(File(path).readAsStringSync(), 'a,b\n1,2\n');
  });

  test('never overwrites: adds (2), (3)…', () async {
    final first = await saver.save('report.csv', 'first');
    final second = await saver.save('report.csv', 'second');
    final third = await saver.save('report.csv', 'third');
    expect(second, endsWith('report (2).csv'));
    expect(third, endsWith('report (3).csv'));
    expect(File(first).readAsStringSync(), 'first'); // untouched
    expect(File(second).readAsStringSync(), 'second');
  });

  test('folderName is the last part of the folder path', () {
    expect(saver.folderName, folder.uri.pathSegments.where((s) => s.isNotEmpty).last);
  });
}
