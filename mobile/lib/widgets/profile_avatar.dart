import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../auth/session.dart';
import '../theme/app_theme.dart';

const _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.13:8081',
);

/// Holds the signed-in user's profile photo so every avatar updates together.
class ProfilePhotoStore extends ChangeNotifier {
  ProfilePhotoStore._() {
    Session.I.addListener(() {
      if (!Session.I.signedIn) clear();
    });
  }
  static final ProfilePhotoStore I = ProfilePhotoStore._();

  Uint8List? bytes;
  bool loaded = false;
  bool busy = false;

  Map<String, String> get _auth {
    final t = Session.I.token;
    return t == null ? {} : {'Authorization': 'Bearer $t'};
  }

  void clear() {
    bytes = null;
    loaded = false;
    notifyListeners();
  }

  Future<void> load() async {
    if (Session.I.token == null) return;
    loaded = true;
    try {
      final res = await http
          .get(Uri.parse('$_base/api/profile/photo'), headers: _auth)
          .timeout(const Duration(seconds: 15));
      bytes = res.statusCode == 200 && res.bodyBytes.isNotEmpty
          ? res.bodyBytes
          : null;
    } catch (_) {
      bytes = null;
    }
    notifyListeners();
  }

  Future<String?> upload(XFile file) async {
    busy = true;
    notifyListeners();
    try {
      final data = await file.readAsBytes();
      final req =
          http.MultipartRequest('POST', Uri.parse('$_base/api/profile/photo'))
            ..headers.addAll(_auth)
            ..files.add(
              http.MultipartFile.fromBytes(
                'photo',
                data,
                filename: file.name.isEmpty ? 'photo.jpg' : file.name,
              ),
            );
      final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 60)),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await load();
        return null;
      }
      return 'Could not upload the photo (${res.statusCode}).';
    } catch (_) {
      return 'Could not upload the photo. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> remove() async {
    busy = true;
    notifyListeners();
    try {
      final res = await http
          .delete(Uri.parse('$_base/api/profile/photo'), headers: _auth)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        bytes = null;
        return null;
      }
      return 'Could not remove the photo (${res.statusCode}).';
    } catch (_) {
      return 'Could not remove the photo. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

/// Round avatar: real photo if present, otherwise the first letter of the name.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.onTap,
    this.onDark = true,
  });
  final String name;
  final double size;
  final VoidCallback? onTap;
  final bool onDark;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  @override
  void initState() {
    super.initState();
    final s = ProfilePhotoStore.I;
    if (!s.loaded) s.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfilePhotoStore.I,
      builder: (context, _) {
        final store = ProfilePhotoStore.I;
        final initial = widget.name.trim().isEmpty
            ? '?'
            : widget.name.trim().characters.first.toUpperCase();
        final circle = Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.onDark
                ? Colors.white.withValues(alpha: .2)
                : AppColors.primary,
            border: Border.all(
              color: widget.onDark
                  ? Colors.white.withValues(alpha: .5)
                  : AppColors.gold,
              width: 2,
            ),
            image: store.bytes == null
                ? null
                : DecorationImage(
                    image: MemoryImage(store.bytes!),
                    fit: BoxFit.cover,
                  ),
          ),
          child: store.bytes != null
              ? null
              : store.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.size * .4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        );
        if (widget.onTap == null) return circle;
        return InkWell(
          mouseCursor: SystemMouseCursors.click,
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              circle,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 12,
                    color: AppColors.deep,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet: choose from gallery, change or remove the photo.
Future<void> showPhotoSheet(BuildContext context) async {
  final store = ProfilePhotoStore.I;
  final messenger = ScaffoldMessenger.of(context);
  final action = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SimpleDialog(
      title: const Text('Profile photo'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'pick'),
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined),
              const SizedBox(width: 12),
              Text(store.bytes == null ? 'Choose from gallery' : 'Change photo'),
            ],
          ),
        ),
        if (store.bytes != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'remove'),
            child: const Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                SizedBox(width: 12),
                Text('Remove photo'),
              ],
            ),
          ),
      ],
    ),
  );
  String? err;
  if (action == 'pick') {
    XFile? f;
    try {
      f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open your photo library. Check photo permission and try again.'),
        ),
      );
      return;
    }
    if (f == null) return;
    err = await store.upload(f);
  } else if (action == 'remove') {
    err = await store.remove();
  } else {
    return;
  }
  if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
}

/// Avatar for the Home summary card: uploaded photo, else gender icon, else neutral.
class ProfileSummaryAvatar extends StatefulWidget {
  const ProfileSummaryAvatar({super.key, required this.gender});
  final String gender;

  @override
  State<ProfileSummaryAvatar> createState() => _ProfileSummaryAvatarState();
}

class _ProfileSummaryAvatarState extends State<ProfileSummaryAvatar> {
  @override
  void initState() {
    super.initState();
    final s = ProfilePhotoStore.I;
    if (!s.loaded) s.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfilePhotoStore.I,
      builder: (context, _) {
        final bytes = ProfilePhotoStore.I.bytes;
        final icon = switch (widget.gender) {
          'male' => Icons.face_4_rounded,
          'female' => Icons.face_3_rounded,
          _ => Icons.person_rounded,
        };
        return CircleAvatar(
          radius: 27,
          backgroundColor: AppColors.lavender,
          foregroundImage: bytes == null ? null : MemoryImage(bytes),
          child: Icon(icon, color: AppColors.primary, size: 30),
        );
      },
    );
  }
}
