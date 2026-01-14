import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../services/shopping_list_collection_helper.dart';
import '../theme/app_colors.dart';

class CategoryItemsScreen extends StatefulWidget {
  final String categoryTitle;
  final String firestoreCategory;
  final String? initialSearchQuery;

  const CategoryItemsScreen({
    super.key,
    required this.categoryTitle,
    required this.firestoreCategory,
    this.initialSearchQuery,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late Animation<double> _gradientShift;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchQuery ?? '';

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _gradientShift = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _searchController.dispose();
    super.dispose();
  }

 

  Future<CollectionReference<Map<String, dynamic>>> _getItemsCollection() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final familyId = userDoc.data()?['familyId'];

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



  Future<void> _addItemToShoppingList(String name) async {
    final ref = await ShoppingListCollectionHelper.getShoppingListCollection();

    final normalizedName = name.trim().toLowerCase();
    final existing = await ref.get();

    final alreadyExists = existing.docs.any((doc) {
      final existingName = (doc.data()['name'] ?? '').toString().toLowerCase();
      return existingName == normalizedName;
    });

    if (alreadyExists) return;

    await ref.add({
      'name': name,
      'checked': false,
      'added_at': FieldValue.serverTimestamp(),
      'from_usage': true,
    });
  }

  void _showUseItemPopup({
    required BuildContext context,
    required String itemName,
    required double currentPercent,
    required DocumentReference itemRef,
  }) {
    double sliderValue = currentPercent;
    bool addToShoppingList = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  Text(
                    itemName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onVerticalDragUpdate: (details) {
                          setModalState(() {
                            sliderValue -= details.delta.dy;
                            sliderValue = sliderValue.clamp(0, 100);
                          });
                        },
                        child: Container(
                          width: 72,
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              
                              Container(
                                width: double.infinity,
                                height: 220 * (sliderValue / 100),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: sliderValue <= 20
                                        ? [
                                      Colors.red.shade700,
                                      Colors.red.shade400,
                                    ]
                                        : sliderValue <= 50
                                        ? [
                                      Colors.orange.shade700,
                                      Colors.orange.shade400,
                                    ]
                                        : [
                                      Colors.green.shade700,
                                      Colors.green.shade400,
                                    ],
                                  ),
                                ),
                              ),

                          
                              Center(
                                child: Text(
                                  '${sliderValue.toInt()}%',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: sliderValue < 55
                                        ? Colors.black54
                                        : Colors.white.withAlpha(230),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  CheckboxListTile(
                    value: addToShoppingList,
                    onChanged: (value) {
                      setModalState(() {
                        addToShoppingList = value ?? false;
                      });
                    },
                    title: const Text(
                      'Add to shopping list',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final int newPercent = sliderValue.round();

                        if (addToShoppingList) {
                          await _addItemToShoppingList(itemName);
                          await itemRef.update({
                            'skip_suggested_buy': true,
                          });
                        }

                        if (newPercent <= 0) {
                          await itemRef.delete();
                        } else {
                          await itemRef.update({
                            'remaining_percent': newPercent,
                          });
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Use',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.categoryTitle)),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search in category',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),

    
      body: FutureBuilder<CollectionReference<Map<String, dynamic>>>(
        future: _getItemsCollection(),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final itemsCollection = collectionSnapshot.data!;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: itemsCollection
                .where('category', isEqualTo: widget.firestoreCategory)
                .orderBy('purchase_date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              final query = _searchController.text.toLowerCase().trim();
              final filteredDocs = docs.where((doc) {
                if (query.isEmpty) return true;
                final name =
                (doc.data()['name'] ?? '').toString().toLowerCase();
                return query.split(' ').every(name.contains);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('No items found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data();

                  final double remainingPercent =
                  ((data['remaining_percent'] as num?)?.toDouble() ?? 100)
                      .clamp(0, 100);

                  final String name = data['name'] ?? 'Unknown';
                  final int expiryDays =
                      (data['expiry_days'] as num?)?.toInt() ?? 7;

                  final Timestamp? ts =
                  data['purchase_date'] as Timestamp?;
                  final DateTime expiryDate =
                  (ts?.toDate() ?? DateTime.now())
                      .add(Duration(days: expiryDays));

                  final int remainingDays =
                  ((expiryDate.difference(DateTime.now()).inHours) / 24)
                      .ceil();

                  if (remainingDays <= 0) return const SizedBox.shrink();

                  final bool isExpiringSoon = remainingDays <= 3;
                  final Color expiryColor =
                  isExpiringSoon ? Colors.orange : Colors.green;

                  return Slidable(
                    key: ValueKey(doc.id),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (_) async {
                        
                            Slidable.of(context)?.close();

                         
                            await Future.delayed(const Duration(milliseconds: 50));

                            if (!context.mounted) return;

                            _showUseItemPopup(
                              context: context,
                              itemName: name,
                              currentPercent: remainingPercent,
                              itemRef: doc.reference,
                            );
                          },
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          icon: Icons.check_circle_outline,
                          label: 'Use',
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: expiryColor.withAlpha(31),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.timer_outlined,
                                color: expiryColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$remainingDays days left',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: expiryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
