import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_grocery/services/shopping_list_collection_helper.dart';
import 'package:smart_grocery/theme/app_typography.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _controller = TextEditingController();

  User? get user => FirebaseAuth.instance.currentUser;

  // 🔁 Shared / Personal shopping list
  Future<CollectionReference<Map<String, dynamic>>> get _shoppingList async {
    return ShoppingListCollectionHelper.getShoppingListCollection();
  }

  // 🔁 Shared / Personal inventory (for suggested buys)
  Future<CollectionReference<Map<String, dynamic>>> _getItemsCollection() async {
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
      return FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('items');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items');
  }

  // ---------------- ACTIONS ----------------

  void _addItem() async {
    final text = _controller.text.trim();
    if (text.isEmpty || user == null) return;

    final ref = await _shoppingList;
    await ref.add({
      'name': text,
      'checked': false,
      'added_at': FieldValue.serverTimestamp(),
      'addedBy': user!.uid,           // ✅ added
      'from_usage': false,            // ✅ manual entry
    });

    _controller.clear();
  }

  void _toggleItem(String id, bool current) async {
    final ref = await _shoppingList;
    await ref.doc(id).update({'checked': !current});
  }

  void _deleteItem(String id) async {
    final ref = await _shoppingList;
    await ref.doc(id).delete();
  }

  Future<void> _clearCheckedItems() async {
    final ref = await _shoppingList;
    final snapshot = await ref.where('checked', isEqualTo: true).get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping List', style: AppTextStyles.sectionHeader),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearCheckedItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Item
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _addItem(),
              decoration: InputDecoration(
                hintText: 'Add an item',
                prefixIcon: const Icon(Icons.add_shopping_cart_outlined),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ---------------- SUGGESTED BUYS ----------------
          FutureBuilder<CollectionReference<Map<String, dynamic>>>(
            future: _getItemsCollection(),
            builder: (context, itemsRefSnapshot) {
              if (!itemsRefSnapshot.hasData) return const SizedBox();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: itemsRefSnapshot.data!.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final suggested = snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    final remaining =
                        (data['remaining_percent'] as num?)?.toDouble() ?? 100;
                    final skip = data['skip_suggested_buy'] == true;
                    return !skip && remaining > 0 && remaining <= 20;
                  }).toList();

                  if (suggested.isEmpty) return const SizedBox();

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suggested Buys',
                          style: AppTextStyles.sectionHeader,
                        ),
                        const SizedBox(height: 8),
                        ...suggested.map((doc) {
                          final data = doc.data();
                          final remaining =
                              (data['remaining_percent'] as num?)?.toDouble() ??
                                  100;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.trending_down,
                                    color: Colors.orange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    data['name'] ?? '',
                                    style: AppTextStyles.body,
                                  ),
                                ),
                                Text(
                                  '${remaining.toInt()}%',
                                  style: AppTextStyles.helper.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // ---------------- SHOPPING LIST ----------------
          Expanded(
            child: FutureBuilder<CollectionReference<Map<String, dynamic>>>(
              future: _shoppingList,
              builder: (context, refSnapshot) {
                if (!refSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: refSnapshot.data!.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ac = a.data()['checked'] ?? false;
                        final bc = b.data()['checked'] ?? false;
                        return ac == bc ? 0 : ac ? 1 : -1;
                      });

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Your shopping list is empty'),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final data = doc.data();

                        return Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteItem(doc.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.redAccent,
                            child:
                            const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: ListTile(
                            leading: GestureDetector(
                              onTap: () =>
                                  _toggleItem(doc.id, data['checked'] ?? false),
                              child: Icon(
                                data['checked'] == true
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: data['checked'] == true
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            title: Text(
                              data['name'] ?? '',
                              style: AppTextStyles.shoppingItem(
                                  data['checked'] ?? false),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
