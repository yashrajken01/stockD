import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:smart_grocery/theme/app_colors.dart';
import 'package:smart_grocery/theme/app_typography.dart';

class ManualAddItemScreen extends StatefulWidget {
  const ManualAddItemScreen({super.key});

  @override
  State<ManualAddItemScreen> createState() => _ManualAddItemScreenState();
}

class _ManualAddItemScreenState extends State<ManualAddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  DateTime? _expiryDate;
  bool _detectingCategory = false;
  bool _savingAll = false;

  String _selectedCategory = 'Pantry';
  Timer? _debounce;

  final List<String> _categories = [
    'Dairy',
    'Fruit or Vegetable',
    'Packaged Food',
    'Pantry',
    'Frozen',
  ];

  final List<Map<String, dynamic>> _previewItems = [];

  // ---------------- GEMINI CATEGORY ----------------

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _detectCategory(value);
    });
  }

  Future<void> _detectCategory(String itemName) async {
    if (itemName.trim().isEmpty) return;

    setState(() => _detectingCategory = true);

    final prompt = '''
Classify the grocery item "$itemName" into ONE category:
Dairy, Fruit or Vegetable, Packaged Food, Pantry, Frozen
Respond with ONLY the category name.
''';

    try {
      final response = await Gemini.instance.text(prompt);
      final output = response?.output?.trim();

      if (output != null && _categories.contains(output)) {
        setState(() => _selectedCategory = output);
      }
    } catch (_) {
      // fail silently
    } finally {
      if (mounted) setState(() => _detectingCategory = false);
    }
  }

  // ---------------- ADD TO PREVIEW ----------------

  void _addToPreview() {
    if (!_formKey.currentState!.validate() || _expiryDate == null) return;

    final expiryDays =
    ((_expiryDate!.difference(DateTime.now()).inHours) / 24).ceil();

    if (expiryDays <= 0) return;

    setState(() {
      _previewItems.add({
        'name': _nameController.text.trim(),
        'expiry_days': expiryDays,
        'category': _selectedCategory,
      });

      _nameController.clear();
      _expiryDate = null;
      _selectedCategory = 'Pantry';
    });
  }

  // ---------------- SAVE ALL ----------------

  Future<void> _saveAllItems() async {
    if (_previewItems.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _savingAll = true);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final String? familyId = userDoc.data()?['familyId'];

    final CollectionReference itemsRef = familyId != null
        ? FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('items')
        : FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items');

    final batch = FirebaseFirestore.instance.batch();

    for (final item in _previewItems) {
      final docRef = itemsRef.doc();
      batch.set(docRef, {
        'name': item['name'],
        'category': item['category'],
        'purchase_date': FieldValue.serverTimestamp(),
        'expiry_days': item['expiry_days'],
        'remaining_percent': 100,
        'notification_dismissed': false,
        'skip_suggested_buy': false,
      });
    }

    await batch.commit();

    if (mounted) Navigator.pop(context);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Manual Entry'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    onChanged: _onNameChanged,
                    decoration:
                    const InputDecoration(labelText: 'Item name'),
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
                  ),

                  if (_detectingCategory)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Detecting category...',
                          style: AppTextStyles.helper,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategory = v!),
                    decoration:
                    const InputDecoration(labelText: 'Category'),
                  ),

                  const SizedBox(height: 12),

                  ListTile(
                    title: Text(
                      _expiryDate == null
                          ? 'Select expiry date'
                          : 'Expiry: ${_expiryDate!.toLocal().toString().split(' ')[0]}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                        DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _expiryDate = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _addToPreview,
                    icon: const Icon(Icons.add),
                    label: const Text('Add to preview'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: _previewItems.isEmpty
                  ? const Center(child: Text('No items added yet'))
                  : ListView.builder(
                itemCount: _previewItems.length,
                itemBuilder: (_, i) {
                  final item = _previewItems[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text(item['category']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () {
                          setState(() => _previewItems.removeAt(i));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                _savingAll || _previewItems.isEmpty ? null : _saveAllItems,
                child: _savingAll
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save all items'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
