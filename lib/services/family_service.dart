import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyService {
  /// Returns current user's familyId if exists, otherwise null
  static Future<String?> getCurrentFamilyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return null;

    final data = userDoc.data();
    final familyId = data?['familyId'];

    if (familyId is String && familyId.isNotEmpty) {
      return familyId;
    }

    return null;
  }

  /// Convenience helper
  static Future<bool> isInFamily() async {
    final familyId = await getCurrentFamilyId();
    return familyId != null;
  }
}
