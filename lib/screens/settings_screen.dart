import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'login_screen.dart';
import 'family_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  bool _notificationsEnabled = true;
  int _expiryReminderDays = 3;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // ================= LOAD PREFS =================

  Future<void> _loadPreferences() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    setState(() {
      _notificationsEnabled = data['notificationsEnabled'] ?? true;
      _expiryReminderDays = data['expiryReminderDays'] ?? 3;
    });
  }

  Future<void> _savePreferences() async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({
      'notificationsEnabled': _notificationsEnabled,
      'expiryReminderDays': _expiryReminderDays,
    }, SetOptions(merge: true));
  }

  // ================= CHANGE NAME =================

  Future<void> _changeName() async {
    final controller =
    TextEditingController(text: user?.displayName ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || user == null) return;

    // 🔹 Update Firebase Auth
    await user!.updateDisplayName(newName);

    // 🔹 Update Firestore (source of truth for family screen)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({'displayName': newName}, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {}); // refresh UI

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name updated successfully')),
    );
  }

  // ================= LOGOUT =================

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
          (_) => false,
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: AppTextStyles.sectionHeader,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ================= ACCOUNT =================
          _sectionTitle('Account'),

          _infoTile(
            icon: Icons.person_outline,
            title: 'Name',
            value: user?.displayName ?? 'Not set',
            onTap: _changeName,
          ),

          _infoTile(
            icon: Icons.email_outlined,
            title: 'Email',
            value: user?.email ?? '',
          ),

          _actionTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: () {
              if (user?.email == null) return;
              FirebaseAuth.instance
                  .sendPasswordResetEmail(email: user!.email!);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset email sent'),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // ================= PREFERENCES =================
          _sectionTitle('Preferences'),

          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _savePreferences();
            },
            title: const Text('Notifications'),
            secondary: const Icon(Icons.notifications_outlined),
          ),

          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Expiry Reminder'),
            subtitle: Text('$_expiryReminderDays days before'),
            trailing: DropdownButton<int>(
              value: _expiryReminderDays,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day')),
                DropdownMenuItem(value: 3, child: Text('3 days')),
                DropdownMenuItem(value: 5, child: Text('5 days')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _expiryReminderDays = value);
                _savePreferences();
              },
            ),
          ),

          const SizedBox(height: 28),

          // ================= FAMILY =================
          _sectionTitle('Family'),

          _actionTile(
            icon: Icons.people_outline,
            title: 'Family Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyScreen()),
              );
            },
          ),

          const SizedBox(height: 28),

          // ================= APP =================
          _sectionTitle('App'),

          _infoTile(
            icon: Icons.info_outline,
            title: 'App Version',
            value: '1.0.0',
          ),

          const SizedBox(height: 28),

          // ================= LOGOUT =================
          _actionTile(
            icon: Icons.logout,
            title: 'Logout',
            isDestructive: true,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  // ================= HELPERS =================

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.sectionHeader),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: onTap != null ? const Icon(Icons.edit) : null,
      onTap: onTap,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : null,
        ),
      ),
      onTap: onTap,
    );
  }
}
