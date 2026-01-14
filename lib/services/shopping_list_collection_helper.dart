import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingListCollectionHelper {
  static Future<CollectionReference<Map<String, dynamic>>> getShoppingListCollection() async {
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
      // 🔥 SHARED FAMILY SHOPPING LIST
      return FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('shopping_list');
    }

    // 👤 PERSONAL SHOPPING LIST
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopping_list');
  }
}
