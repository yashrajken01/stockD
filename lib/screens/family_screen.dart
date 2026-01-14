import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _codeController = TextEditingController();

  String? _familyId;
  String? _joinCode;
  List<String> _memberNames = [];

  bool _isLoading = false;

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }


  Future<void> _loadFamily() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final familyId = userDoc.data()?['familyId'];

      if (familyId == null) {
        setState(() {
          _familyId = null;
          _memberNames.clear();
        });
        return;
      }

      final familyDoc = await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .get();

      if (!familyDoc.exists) {
        setState(() => _familyId = null);
        return;
      }

      final data = familyDoc.data()!;
      final members = List<String>.from(data['members'] ?? []);

      final names = <String>[];
      for (final uid in members) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        names.add(
          doc.data()?['displayName'] ??
              doc.data()?['email'] ??
              'Member',
        );
      }

      setState(() {
        _familyId = familyId;
        _joinCode = data['joinCode'];
        _memberNames = names;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _createFamily() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    final familyId = const Uuid().v4();
    final joinCode = familyId.substring(0, 6).toUpperCase();

    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .set({
      'joinCode': joinCode,
      'members': [user!.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({'familyId': familyId}, SetOptions(merge: true));

    await _loadFamily();
  }


  Future<void> _joinFamily() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6 || user == null) return;

    setState(() => _isLoading = true);

    final query = await FirebaseFirestore.instance
        .collection('families')
        .where('joinCode', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid family code')),
      );
      return;
    }

    final familyDoc = query.docs.first;

    await familyDoc.reference.update({
      'members': FieldValue.arrayUnion([user!.uid]),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({'familyId': familyDoc.id}, SetOptions(merge: true));

    await _loadFamily();
  }


  Future<void> _leaveFamily() async {
    if (user == null || _familyId == null) return;

    setState(() => _isLoading = true);

    await FirebaseFirestore.instance
        .collection('families')
        .doc(_familyId)
        .update({
      'members': FieldValue.arrayRemove([user!.uid]),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .update({'familyId': FieldValue.delete()});

    setState(() {
      _familyId = null;
      _memberNames.clear();
    });

    setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'My Family',
          style: AppTextStyles.sectionHeader,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: _familyId == null
            ? _buildNoFamilyUI()
            : _buildFamilyUI(),
      ),
    );
  }


  Widget _buildNoFamilyUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            children: [
              Text('Create a Family', style: AppTextStyles.sectionHeader),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _createFamily,
                child: const Text('Create Family'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          child: Column(
            children: [
              Text('Join Existing Family', style: AppTextStyles.sectionHeader),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  hintText: 'Enter 6-digit code',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _joinFamily,
                child: const Text('Join Family'),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildFamilyUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),

        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Family Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _joinCode ?? '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Family Members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),


        Expanded(
          child: ListView.builder(
            itemCount: _memberNames.length,
            itemBuilder: (_, i) {
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      _memberNames[i][0].toUpperCase(),
                    ),
                  ),
                  title: Text(_memberNames[i]),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: SizedBox(
            width: 220,
            child: ElevatedButton(
              onPressed: _leaveFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Leave Family',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
