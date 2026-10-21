import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class ProfileIdentityEditor extends StatefulWidget {
  final AuthProvider auth;
  final double avatarRadius;
  final Color? nameColor;

  const ProfileIdentityEditor({
    super.key,
    required this.auth,
    this.avatarRadius = 40,
    this.nameColor,
  });

  @override
  State<ProfileIdentityEditor> createState() => _ProfileIdentityEditorState();
}

class _ProfileIdentityEditorState extends State<ProfileIdentityEditor> {
  bool _busy = false;

  Future<void> _choosePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null || !mounted) return;
      setState(() => _busy = true);
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showMessage('Choose a photo smaller than 5 MB.', isError: true);
        return;
      }
      final extension = image.name.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      final url = await AuthService().uploadProfilePhoto(
        userId: widget.auth.userId,
        bytes: bytes,
        extension: extension,
      );
      await widget.auth.updateProfile(avatarUrl: url);
    } catch (error) {
      _showMessage(AuthService.formatProfilePhotoError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: widget.auth.userName);
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit your name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (value) =>
                (value ?? '').trim().length < 2 ? 'Enter your name.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    try {
      await widget.auth.updateProfile(fullName: controller.text);
      _showMessage('Your name has been updated.');
    } catch (error) {
      _showMessage(AuthService.formatAuthErrorMessage(error), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.accentRed : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final avatarUrl = auth.profile?.avatarUrl;
    final initials = auth.userName.trim().isEmpty
        ? '?'
        : auth.userName.trim()[0].toUpperCase();
    final avatar = CircleAvatar(
      radius: widget.avatarRadius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                fontSize: widget.avatarRadius * .8,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : null,
    );

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatar,
            Material(
              color: AppTheme.accentBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _busy ? null : _choosePhoto,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                auth.userName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color:
                      widget.nameColor ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit name',
              visualDensity: VisualDensity.compact,
              onPressed: _editName,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: _busy ? null : _choosePhoto,
          icon: const Icon(Icons.add_a_photo_outlined, size: 17),
          label: Text(avatarUrl == null ? 'Add profile photo' : 'Change photo'),
        ),
      ],
    );
  }
}
