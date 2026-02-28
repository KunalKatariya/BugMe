import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/app_providers.dart';

class PersonalScreen extends ConsumerStatefulWidget {
  const PersonalScreen({super.key});

  @override
  ConsumerState<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends ConsumerState<PersonalScreen> {
  late final TextEditingController _nameCtrl;
  late String _selectedAvatar;

  // Avatar options — __logo__ sentinel first, then emojis
  static const _avatarOptions = [
    '__logo__',
    '🙂', '😊', '😎', '🤩', '🥳', '😏', '🧐', '🤓',
    '🧑', '👦', '👧', '👨', '👩', '🧔', '👱', '🧕',
    '🐱', '🐶', '🦊', '🐼', '🦁', '🐨', '🐸', '🐯',
    '🌟', '🔥', '💎', '🚀', '🎯', '💡', '⚡', '🌈',
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nameCtrl = TextEditingController(text: profile.name);
    _selectedAvatar = profile.avatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await ref.read(userProfileProvider.notifier).setName(name);
    await ref.read(userProfileProvider.notifier).setAvatar(_selectedAvatar);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Profile updated'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        title: Text('Personal', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar preview (large, centered) ─────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withAlpha(12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cs.outline.withAlpha(80), width: 2),
                    ),
                    child: _selectedAvatar == '__logo__'
                        ? ClipOval(
                            child: Image.asset('assets/images/logo.png',
                                fit: BoxFit.cover, width: 90, height: 90))
                        : Center(
                            child: Text(_selectedAvatar,
                                style: const TextStyle(fontSize: 44))),
                  ),
                  const SizedBox(height: 10),
                  Text('Tap an emoji below to change',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Emoji grid ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Text('CHOOSE AVATAR',
                  style: tt.labelMedium?.copyWith(
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant)),
            ),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline, width: 0.5),
              ),
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _avatarOptions.length,
                itemBuilder: (_, i) {
                  final emoji = _avatarOptions[i];
                  final isSelected = emoji == _selectedAvatar;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.onSurface.withAlpha(18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: cs.onSurface.withAlpha(60), width: 1.5)
                            : null,
                      ),
                      child: emoji == '__logo__'
                          ? Padding(
                              padding: const EdgeInsets.all(3),
                              child: ClipOval(
                                child: Image.asset('assets/images/logo.png',
                                    fit: BoxFit.cover)))
                          : Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 22))),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // ── Name field ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Text('DISPLAY NAME',
                  style: tt.labelMedium?.copyWith(
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant)),
            ),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  border: InputBorder.none,
                  hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: cs.onSurface,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Profile',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
