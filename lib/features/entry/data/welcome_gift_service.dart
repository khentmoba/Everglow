import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_stream_utils.dart';
import '../../../core/utils/logger.dart';

/// Private gift content and its receipt stay in the recipient's own progress.
class WelcomeGiftService {
  final FirebaseFirestore? _firestore;
  WelcomeGiftService({FirebaseFirestore? firestore}) : _firestore = firestore;

  DocumentReference<Map<String, dynamic>> _gift(String uid) =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc('welcome_gift');

  static String? recipientUid({
    required String? username,
    required String? uid,
    required bool authenticated,
    required bool agentSession,
  }) =>
      !agentSession && authenticated && username == 'clairjassen' ? uid : null;

  Future<String?> pendingHtml(String uid) async {
    try {
      // Server-only prevents a stale device cache from replaying a finished gift.
      final snapshot = await withGetTimeout(
        _gift(uid).get(const GetOptions(source: Source.server)),
        label: 'welcome gift',
      );
      final data = snapshot.data();
      if (data == null ||
          data['enabled'] != true ||
          data['completedAt'] != null) {
        return null;
      }
      final html = data['html'];
      if (html is! String || html.trim().isEmpty || html.length > 500000) {
        Logger.w('Welcome gift has no usable HTML.');
        return null;
      }
      return html;
    } catch (error, stack) {
      Logger.e('Could not load welcome gift', error: error, stackTrace: stack);
      return null;
    }
  }

  Future<void> complete(String uid) => withGetTimeout(
    _gift(uid).update({'completedAt': FieldValue.serverTimestamp()}),
    label: 'welcome gift receipt',
  );
}
