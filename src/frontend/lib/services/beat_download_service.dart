import 'package:background_downloader/background_downloader.dart';

/// The download side of liking a beat, behind an interface so tests can fake it.
abstract class MediaDownloader {
  /// Downloads [url] into <app support>/[directory]/[filename].
  /// True on success, false on any failure.
  Future<bool> fetch(String url, String directory, String filename);
}

/// background_downloader keeps going when the app gets backgrounded or killed
/// and only places the file at its destination once complete.
class BackgroundMediaDownloader implements MediaDownloader {
  @override
  Future<bool> fetch(String url, String directory, String filename) async {
    final result = await FileDownloader().download(DownloadTask(
      url: url,
      baseDirectory: BaseDirectory.applicationSupport,
      directory: directory,
      filename: filename,
      retries: 3,
    ));
    return result.status == TaskStatus.complete;
  }
}
