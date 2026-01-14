import 'package:flutter/material.dart';
import 'package:smart_grocery/screens/scan_bill_screen.dart';
import 'package:smart_grocery/screens/settings_screen.dart';
import 'package:smart_grocery/screens/shopping_list_screen.dart';
import 'package:smart_grocery/theme/app_colors.dart';
import '../services/shopping_list_collection_helper.dart';
import '../theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_grocery/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_grocery/screens/category_items_screen.dart';
import 'package:smart_grocery/screens/recipe_suggestion_screen.dart';
import 'package:smart_grocery/screens/manual_add_item_screen.dart';
import 'package:smart_grocery/screens/family_screen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _showOptions = false;

  final User? user = FirebaseAuth.instance.currentUser;

  final Map<String, String> categoryMapping = {
    'Dairy & Chilled': 'Dairy',
    'Fresh Produce': 'Fruit or Vegetable',
    'Packaged Goods': 'Packaged Food',
    'Dry Storage': 'Pantry',
    'Frozen Foods': 'Frozen',
  };


  Future<
      CollectionReference<Map<String, dynamic>>> _getItemsCollection() async {
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


  Future<void> _logoutUser(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
          (_) => false,
    );
  }

  
  Stream<int> _getExpiringCountStream() async* {
    final ref = await _getItemsCollection();

    yield* ref
        .where('purchase_date', isNotEqualTo: null)
        .orderBy('purchase_date')
        .snapshots()
        .map((snapshot) {
      int count = 0;
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['notification_dismissed'] == true) continue;

        final ts = data['purchase_date'] as Timestamp?;
        final expiryDays = (data['expiry_days'] as num?)?.toInt() ?? 7;

        if (ts == null) continue;

        final expiryDate = ts.toDate().add(Duration(days: expiryDays));
        final diffDays =
        ((expiryDate
            .difference(now)
            .inHours) / 24).ceil();

        if (diffDays <= 3) count++;
      }
      return count;
    });
  }


  Future<void> _handleSearch(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;

    final ref = await _getItemsCollection();
    final snapshot = await ref.get();

    final matches = snapshot.docs.where((doc) {
      final name = (doc['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();

    if (matches.isEmpty) {
      _showSnack('No items found');
      return;
    }

    final data = matches.first.data();
    final firestoreCategory = data['category'];

    final uiCategory = categoryMapping.entries
        .firstWhere(
          (e) => e.value == firestoreCategory,
      orElse: () => const MapEntry('', ''),
    )
        .key;

    if (uiCategory.isEmpty) {
      _showSnack('Category not found');
      return;
    }

    _searchController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoryItemsScreen(
              categoryTitle: uiCategory,
              firestoreCategory: firestoreCategory,
              initialSearchQuery: q,
            ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }


  void _showExpiringItems() async {
    final ref = await _getItemsCollection();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Items Expiring Soon',
                style: AppTextStyles.sectionHeader),
            content: SizedBox(
              width: double.maxFinite,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref
                    .where('purchase_date', isNotEqualTo: null)
                    .orderBy('purchase_date')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final now = DateTime.now();

                  final expiring = snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    if (data['notification_dismissed'] == true) return false;

                    final ts = data['purchase_date'] as Timestamp?;
                    final expiryDays =
                        (data['expiry_days'] as num?)?.toInt() ?? 7;
                    if (ts == null) return false;

                    final expiryDate =
                    ts.toDate().add(Duration(days: expiryDays));
                    final diff =
                    ((expiryDate
                        .difference(now)
                        .inHours) / 24).ceil();
                    return diff <= 3;
                  }).toList();

                  if (expiring.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No items expiring soon!!',
                          textAlign: TextAlign.center),
                    );
                  }

                  return SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: expiring.length,
                      itemBuilder: (context, i) {
                        final data = expiring[i].data();
                        final ts = data['purchase_date'] as Timestamp;
                        final expiryDays =
                            (data['expiry_days'] as num?)?.toInt() ?? 7;

                        final remainingDays =
                        ((ts
                            .toDate()
                            .add(Duration(days: expiryDays))
                            .difference(DateTime.now())
                            .inHours) /
                            24)
                            .ceil();

                        return Dismissible(
                          key: ValueKey(expiring[i].id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.redAccent,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            final bool? addToCart = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Clear notification'),
                                content: Text(
                                  'Do you want to add "${data['name']}" to your shopping list?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('No'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );

                            if (addToCart == null) return false;

                            if (addToCart) {
                              final ref = await ShoppingListCollectionHelper.getShoppingListCollection();
                              await ref.add({
                                'name': data['name'],
                                'checked': false,
                                'added_at': FieldValue.serverTimestamp(),
                                'from_expiry_notification': true,
                              });
                            }

                            await expiring[i].reference.update({
                              'notification_dismissed': true,
                            });

                            return true;
                          },
                          child: ListTile(
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            title: Text(
                              data['name'] ?? 'Unknown',
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '$remainingDays days left',
                              style: AppTextStyles.helper.copyWith(color: Colors.orange),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Center(
        child: Container(
          width: 360,
          height: 780,
          color: AppColors.surface,
          child: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8,
                              vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                                icon: const Icon(Icons.menu_rounded, size: 28,
                                    color: AppColors.textPrimary),
                              ),
                              Expanded(
                                child: Text(
                                  'stockD',
                                  style: AppTextStyles.appTitle.copyWith(
                                      fontSize: 22),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Stack(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (
                                            _) => const ShoppingListScreen()),
                                      );
                                    },
                                    icon: Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 26,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.subtleCard,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withAlpha(26),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onSubmitted: _handleSearch,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search_rounded,
                                        color: Color(0xFF1B5E20)),
                                    hintText: 'Search groceries...',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: AppColors.subtleCard,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withAlpha(26),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ],
                              ),
                              child: StreamBuilder<int>(
                                stream: _getExpiringCountStream(),
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  return Stack(
                                    children: [
                                      IconButton(
                                        onPressed: _showExpiringItems,
                                        icon: Icon(Icons.notifications_rounded,
                                            size: 26,
                                            color: AppColors.textPrimary),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Categories',
                          style: AppTextStyles.sectionHeader,
                        ),
                      ),

                      const SizedBox(height: 12),

                       Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.95,
                          children: [
                            _buildCategoryCard(
                                'Dairy & Chilled', Icons.local_drink_outlined),
                            _buildCategoryCard(
                                'Fresh Produce', Icons.eco_outlined),
                            _buildCategoryCard(
                                'Packaged Goods', Icons.inventory_2_outlined),
                            _buildCategoryCard(
                                'Dry Storage', Icons.kitchen_outlined),
                            _buildCategoryCard(
                                'Frozen Foods', Icons.ac_unit_outlined),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                    
                      if (_showOptions)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 8,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _showOptions = false;
                                });

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ScanBillScreen()),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt,
                                      color: AppColors.primary,),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Scan Receipt',
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      if (_showOptions)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 8,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _showOptions = false;
                                });

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ManualAddItemScreen(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.edit, color: AppColors.primary,),
                                    const SizedBox(width: 10),
                                    Text('Manual Entry',
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      FloatingActionButton(
                        backgroundColor: AppColors.accent,
                        elevation: 6,
                        shape: const CircleBorder(),
                        onPressed: () {
                          setState(() {
                            _showOptions = !_showOptions;
                          });
                        },
                        child: AnimatedRotation(
                          turns: _showOptions ? 0.125 : 0.0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Center(
                              child: Icon(
                                Icons.add,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    return InkWell(
      onTap: () {
        final firestoreCategory = categoryMapping[title];
        if (firestoreCategory == null) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CategoryItemsScreen(
                  categoryTitle: title,
                  firestoreCategory: firestoreCategory,
                ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.primary,),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: SafeArea(
        child: user == null
            ? const Center(child: Text('Not logged in'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();

            final displayName =
                data?['displayName'] ?? user.email ?? 'User';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.sectionHeader,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: AppTextStyles.helper,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                _drawerItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                _drawerItem(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Quick Recipes',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const RecipeSuggestionScreen(),
                      ),
                    );
                  },
                ),

                _drawerItem(
                  icon: Icons.people_alt_rounded,
                  label: 'My Family',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FamilyScreen(),
                      ),
                    );
                  },
                ),

                _drawerItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const SettingsScreen(),
                      ),
                    );
                  },
                ),

                const Spacer(),
                const Divider(),

                _drawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _logoutUser(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.black87,
      ),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.redAccent : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
