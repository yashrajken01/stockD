import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class RecipeSuggestionScreen extends StatefulWidget {
  const RecipeSuggestionScreen({super.key});

  @override
  State<RecipeSuggestionScreen> createState() =>
      _RecipeSuggestionScreenState();
}

class _RecipeSuggestionScreenState extends State<RecipeSuggestionScreen> {
  bool _isLoading = true;
  String _recipeText = "";
  List<String> _expiringItems = [];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  // ================= FETCH EXPIRING ITEMS (FAMILY-AWARE) =================

  Future<List<String>> _fetchExpiringItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();

    // 🔹 check if user is in family
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final String? familyId = userDoc.data()?['familyId'];

    final CollectionReference<Map<String, dynamic>> itemsRef =
    familyId != null
        ? FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('items')
        : FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items');

    final snapshot = await itemsRef.get();

    final List<String> items = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final Timestamp? purchaseTs = data['purchase_date'];
      final int expiryDays =
          (data['expiry_days'] as num?)?.toInt() ?? 7;

      if (purchaseTs == null) continue;

      final expiryDate =
      purchaseTs.toDate().add(Duration(days: expiryDays));

      final int daysLeft =
      ((expiryDate.difference(now).inHours) / 24).ceil();

      if (daysLeft >= 0 && daysLeft <= 3) {
        items.add(data['name']);
      }
    }

    return items;
  }

  // ================= GEMINI =================

  Future<String> _getRecipesFromGemini(List<String> items) async {
    if (items.isEmpty) {
      return "No items are expiring soon.";
    }

    final prompt = """
You are an expert Indian home cooking assistant.

Suggest 3 detailed Indian-style recipes using ONLY these ingredients:
${items.join(', ')}

Rules:
- Simple home cooking
- Clear step-by-step instructions (not too long, not too short)
- Explain what to do
- Mention serving tips
- No extra ingredients
- Plain text only

Format EXACTLY like this:

Recipe Name: <name>
Steps:
1. ...
2. ...
Serving Tip: ...
""";

    final response = await Gemini.instance.text(prompt);
    return response?.output ?? "";
  }

  // ================= LOAD =================

  Future<void> _loadRecipes() async {
    final items = await _fetchExpiringItems();
    final recipes = await _getRecipesFromGemini(items);

    if (!mounted) return;

    setState(() {
      _expiringItems = items;
      _recipeText = recipes;
      _isLoading = false;
    });
  }

  // ================= UI HELPERS =================

  List<Widget> _buildRecipeCards() {
    final sections = _recipeText
        .split('Recipe Name:')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return sections.map((section) {
      final lines = section.trim().split('\n');
      final title = lines.first.trim();
      final body = lines.skip(1).join('\n').trim();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.sectionHeader),
            const SizedBox(height: 10),
            Text(
              body,
              style: AppTextStyles.body.copyWith(height: 1.7),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        title: Text(
          'Recipe Suggestions',
          style: AppTextStyles.sectionHeader.copyWith(fontSize: 20),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Thinking of delicious recipes...',
                style: AppTextStyles.body,
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_expiringItems.isNotEmpty) ...[
              Text(
                'Use these before they expire',
                style: AppTextStyles.sectionHeader,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _expiringItems
                    .map(
                      (item) => Chip(
                    label: Text(item, style: AppTextStyles.body),
                    backgroundColor: AppColors.subtleCard,
                  ),
                )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Suggested Recipes',
              style: AppTextStyles.sectionHeader,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _buildRecipeCards(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

