import 'dart:io';

/// Saves a file the user asked for (the CSV export). Screens only use this interface, so
/// they never touch the file system; tests pass a fake, and Android later gets its own.
abstract class FileSaver {
  /// Writes [content] as [fileName] and returns the full path of the saved file.
  Future<String> save(String fileName, String content);

  /// Where files go, for messages like "Saved … to Downloads".
  String get folderName;
}

/// Desktop: saves into the user's Downloads folder (falls back to the home folder when
/// there is none). Never overwrites: "report.csv" becomes "report (2).csv", "report (3).csv"…
/// Uses only `dart:io`, no extra package.
class DownloadsFileSaver implements FileSaver {
  /// The folder to save in. Null = the user's Downloads folder (tests pass a temp folder).
  final Directory? directory;

  DownloadsFileSaver({this.directory});

  Directory get _folder {
    if (directory != null) return directory!;
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
    final downloads = Directory('$home${Platform.pathSeparator}Downloads');
    return downloads.existsSync() ? downloads : Directory(home);
  }

  @override
  String get folderName => _folder.uri.pathSegments.where((s) => s.isNotEmpty).last;

  @override
  Future<String> save(String fileName, String content) async {
    final folder = _folder;
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    final extension = dot == -1 ? '' : fileName.substring(dot);
    var file = File('${folder.path}${Platform.pathSeparator}$fileName');
    for (var n = 2; file.existsSync(); n++) {
      file = File('${folder.path}${Platform.pathSeparator}$base ($n)$extension');
    }
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}
