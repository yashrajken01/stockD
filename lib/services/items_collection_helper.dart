import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ItemsCollectionHelper {
  static Future<CollectionReference<Map<String, dynamic>>> getItemsCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final familyId = userDoc.data()?['familyId'] as String?;

    if (familyId != null) {
      // 🔥 SHARED FAMILY INVENTORY
      return FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('items');
    }

    // 👤 PERSONAL INVENTORY
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items');
  }
}