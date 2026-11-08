import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> shareText({required String title, required String text}) {
    return SharePlus.instance.share(
      ShareParams(title: title, subject: title, text: text),
    );
  }

  Future<void> shareAudio({required String title, required String path}) {
    return SharePlus.instance.share(
      ShareParams(title: title, subject: title, files: <XFile>[XFile(path)]),
    );
  }
}
