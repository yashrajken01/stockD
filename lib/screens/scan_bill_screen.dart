import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/app_typography.dart';

class ScanBillScreen extends StatefulWidget {
  const ScanBillScreen({super.key});

  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;

  final List<_ScannedItem> _items = [];
  final Map<String, TextEditingController> _expiryControllers = {};
  final _formKey = GlobalKey<FormState>();

  // ================= CATEGORY NORMALIZER =================

  String _normalizeCategory(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dairy and chilled':
        return 'Dairy';
      case 'fresh produce':
        return 'Fruit or Vegetable';
      case 'packaged goods':
        return 'Packaged Food';
      case 'dry storage':
        return 'Pantry';
      case 'frozen foods':
        return 'Frozen';
      default:
        return 'Pantry'; // safe fallback
    }
  }

  // ================= IMAGE PICK =================

  Future<void> _pickImage() async {
    Uint8List? bytes;

    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      bytes = result?.files.single.bytes;
    } else {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final image = await ImagePicker().pickImage(source: source);
      if (image != null) {
        bytes = await File(image.path).readAsBytes();
      }
    }

    if (bytes == null) return;

    setState(() {
      _imageBytes = bytes;
      _items.clear();
      _expiryControllers.clear();
      _error = null;
    });

    await _processImage();
  }

  // ================= GEMINI OCR =================

  Future<void> _processImage() async {
    if (_imageBytes == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await Gemini.instance.textAndImage(
        modelName: 'models/gemini-1.5-flash-latest',
        text: '''
You are a smart grocery receipt scanner.

TASK:
From the receipt image:
1.Extract grocery items
2.Simplify their names
3.Decide realistic expiry days for each item
4.Assign ONE category per item

CATEGORY(choose ONE only):
- Dairy and Chilled
- Fresh Produce
- Packaged Goods
- Dry Storage
- Frozen Foods
- Miscellaneous

NAME SIMPLIFICATION RULES: 
- Remove quantities and units (1L, 500G, KG, PCS, ML) 
- Remove packaging words (PCH, PKT, PP, PACK, FREE, OFFER) 
- Keep Brand + Core Product only 
- Use clean Title Case 
- Avoid duplicates 
- Do NOT invent items

EXPIRY LOGIC (IMPORTANT): 
- Decide expiryDays realistically based on the product name 
- Assume item is freshly purchased today 
- Use common household storage conditions 
- Use whole numbers only 
- Do NOT explain your reasoning

OUTPUT RULES: 
- Return ONLY valid JSON 
- No text, no markdown, no comments

FORMAT:
[
  {
    "name": "Amul Toned Milk",
    "category": "Dairy and Chilled",
    "expiryDays": 3
  },
  {
    "name": "Amul Dahi",
    "category": "Dairy and Chilled",
    "expiryDays": 5
  }
]

Return ONLY JSON.
''',
        images: [_imageBytes!],
      );

      var text = response?.output;
      if (text == null || text.isEmpty) {
        throw Exception('Empty response');
      }

      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final List data = jsonDecode(text);

      for (final raw in data) {
        final id = DateTime.now().microsecondsSinceEpoch.toString();
        final expiry = (raw['expiryDays'] as num?)?.toInt() ?? 30;

        final item = _ScannedItem(
          id: id,
          name: raw['name'] ?? 'Unknown',
          category: _normalizeCategory(raw['category'] ?? ''),
          expiryDays: expiry,
        );

        _items.add(item);
        _expiryControllers[id] =
            TextEditingController(text: expiry.toString());
      }
    } catch (e) {
      _error = 'Failed to scan receipt. Try a clearer image.';
    }

    setState(() => _isLoading = false);
  }

  // ================= INVENTORY TARGET =================

  Future<CollectionReference<Map<String, dynamic>>> _getItemsCollection() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final familyId = userDoc.data()?['familyId'];

    return familyId != null
        ? FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('items')
        : FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items');
  }

  // ================= SAVE =================

  Future<void> _saveItems() async {
    if (_items.isEmpty || !(_formKey.currentState?.validate() ?? false)) return;

    final ref = await _getItemsCollection();
    final batch = FirebaseFirestore.instance.batch();
    final user = FirebaseAuth.instance.currentUser;

    for (final item in _items) {
      batch.set(ref.doc(), {
        'name': item.name,
        'category': item.category, // ✅ normalized
        'expiry_days': item.expiryDays,
        'purchase_date': FieldValue.serverTimestamp(),
        'remaining_percent': 100,
        'addedBy': user?.uid,
        'notification_dismissed': false,
        'skip_suggested_buy': false,
      });
    }

    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt', style: AppTextStyles.sectionHeader),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_imageBytes!, height: 240),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child:
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            if (_items.isNotEmpty)
              Form(
                key: _formKey,
                child: Column(
                  children: _items.map((item) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.redAccent),
                                  onPressed: () {
                                    _expiryControllers[item.id]?.dispose();
                                    _expiryControllers.remove(item.id);
                                    setState(() => _items.remove(item));
                                  },
                                ),
                              ],
                            ),
                            Text(item.category, style: AppTextStyles.helper),
                            TextFormField(
                              controller: _expiryControllers[item.id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Expiry days',
                              ),
                              validator: (v) =>
                              int.tryParse(v ?? '') != null
                                  ? null
                                  : 'Invalid',
                              onChanged: (v) =>
                              item.expiryDays =
                                  int.tryParse(v) ?? item.expiryDays,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan / Upload Bill'),
              ),
            ),

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveItems,
                  child: const Text('Save to Inventory'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _expiryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}

// ================= MODEL =================

class _ScannedItem {
  final String id;
  final String name;
  final String category;
  int expiryDays;

  _ScannedItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expiryDays,
  });
}
