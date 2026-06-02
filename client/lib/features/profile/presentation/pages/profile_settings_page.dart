import 'package:flutter/material.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';
import '../../domain/entities/user_profile.dart';

/// A premium, responsive user settings screen built using glassmorphism styling
/// and fully localized for English and Hebrew (RTL/LTR dynamic mirroring).
///
/// Features input fields for personal information (First Name, Last Name) and locked
/// credential elements (Email, Role) synced from the authentication provider.
class ProfileSettingsPage extends StatefulWidget {
  /// The global application state notifier.
  final AppStateNotifier appState;

  /// Creates a new [ProfileSettingsPage] instance.
  const ProfileSettingsPage({super.key, required this.appState});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _roleController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFields();
    widget.appState.addListener(_onStateChanged);
  }

  /// Initializes text editing controllers with the current profile data or fallbacks from identity provider.
  void _initFields() {
    final profile = widget.appState.userProfile;
    final currentUser = widget.appState.currentUser;

    // Retrieve default first name and last name from identity provider if profile document is null/empty
    String defaultFirstName = '';
    String defaultLastName = '';
    final displayName =
        widget.appState.currentUser?.displayName ??
        widget.appState.mockUser?['name'];
    if (displayName != null && displayName.trim().isNotEmpty) {
      final nameParts = displayName.trim().split(RegExp(r'\s+'));
      if (nameParts.isNotEmpty) {
        defaultFirstName = nameParts[0];
        if (nameParts.length > 1) {
          defaultLastName = nameParts.sublist(1).join(' ');
        }
      }
    }

    final initialFirstName =
        (profile?.firstName != null && profile!.firstName.isNotEmpty)
        ? profile.firstName
        : defaultFirstName;
    final initialLastName =
        (profile?.lastName != null && profile!.lastName.isNotEmpty)
        ? profile.lastName
        : defaultLastName;

    _firstNameController = TextEditingController(text: initialFirstName);
    _lastNameController = TextEditingController(text: initialLastName);

    // Display names or emails from mock fallback if profile is not synced yet
    final defaultEmail =
        profile?.email ??
        widget.appState.currentUser?.email ??
        widget.appState.mockUser?['email'] ??
        '';
    _emailController = TextEditingController(text: defaultEmail);

    final resolvedRole = profile?.role ?? 'user';
    _roleController = TextEditingController(
      text: resolvedRole == 'admin'
          ? widget.appState.translate('role_admin')
          : widget.appState.translate('role_user'),
    );
  }

  /// Listens to updates in the AppStateNotifier. This is critical for asynchronously
  /// updating the controller values when the user profile document is loaded from Firestore
  /// after the screen has already rendered.
  void _onStateChanged() {
    if (!mounted) return;
    final profile = widget.appState.userProfile;
    setState(() {
      if (profile != null) {
        if (_firstNameController.text.isEmpty && profile.firstName.isNotEmpty) {
          _firstNameController.text = profile.firstName;
        }
        if (_lastNameController.text.isEmpty && profile.lastName.isNotEmpty) {
          _lastNameController.text = profile.lastName;
        }
        if (_emailController.text.isEmpty && profile.email.isNotEmpty) {
          _emailController.text = profile.email;
        }
        final resolvedRoleText = profile.role == 'admin'
            ? widget.appState.translate('role_admin')
            : widget.appState.translate('role_user');
        if (_roleController.text != resolvedRoleText) {
          _roleController.text = resolvedRoleText;
        }
      }
    });
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final currentProfile = widget.appState.userProfile;
      final updatedProfile = UserProfile(
        uid:
            currentProfile?.uid ??
            widget.appState.currentUser?.uid ??
            'mock_uid',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: currentProfile?.email ?? _emailController.text,
        role: currentProfile?.role ?? 'user',
        createdAt: currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.appState.updateUserProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.appState.translate('profile_update_success')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.appState.translate('profile_update_error')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(
            isRtl ? Icons.chevron_right : Icons.chevron_left,
            color: AppColors.primary,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.appState.translate('profile_settings_title'),
          style: AppTypography.headlineMd(
            context,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Atmospheric Radial Glows
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    const Color(0x1F571BC1), // Purple gradient bloom
                    AppColors.baseBg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  child: Form(
                    key: _formKey,
                    child: isDesktop
                        ? _buildDesktopLayout()
                        : _buildMobileLayout(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two-column layout grid for desktop viewports.
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: Column(children: [_buildAvatarCard()])),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildEditableDetailsCard(),
              const SizedBox(height: 20),
              _buildLockedCredentialsCard(),
              const SizedBox(height: 24),
              _buildActionButtons(stackButtons: false),
            ],
          ),
        ),
      ],
    );
  }

  /// Stacked column layout for mobile viewports.
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildAvatarCard(),
        const SizedBox(height: 20),
        _buildEditableDetailsCard(),
        const SizedBox(height: 20),
        _buildLockedCredentialsCard(),
        const SizedBox(height: 24),
        _buildActionButtons(stackButtons: true),
      ],
    );
  }

  /// Avatar Card showing capitalized initial inside a rich gradient border.
  Widget _buildAvatarCard() {
    final profile = widget.appState.userProfile;
    final displayName = profile != null
        ? '${profile.firstName} ${profile.lastName}'
        : (widget.appState.currentUser?.displayName ??
              widget.appState.mockUser?['name'] ??
              'User');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return GlassmorphicCard(
      borderRadius: 20.0,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.transparent,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader =
                            LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ).createShader(
                              const Rect.fromLTWH(0.0, 0.0, 100.0, 50.0),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: AppTypography.headlineMd(
                context,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _roleController.text.toUpperCase(),
                style: AppTypography.labelXs(context, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card with form fields for editable details (First and Last name).
  Widget _buildEditableDetailsCard() {
    return GlassmorphicCard(
      borderRadius: 20.0,
      startBorderColor: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.appState.translate('edit_profile'),
              style: AppTypography.headlineMd(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _firstNameController,
              labelKey: 'first_name',
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Required';
                }
                if (val.length > 50) {
                  return 'Max length is 50';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _lastNameController,
              labelKey: 'last_name',
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Required';
                }
                if (val.length > 50) {
                  return 'Max length is 50';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Card with fields for non-editable credentials (Email and Role).
  Widget _buildLockedCredentialsCard() {
    return GlassmorphicCard(
      borderRadius: 20.0,
      startBorderColor: AppColors.textTertiary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.appState.translate('user_role'),
              style: AppTypography.headlineMd(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.appState.translate('profile_credentials_info'),
              style: AppTypography.bodySm(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _emailController,
              labelKey: 'email',
              enabled: false,
              forceLtr: true, // Lock email field strictly to LTR direction
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _roleController,
              labelKey: 'user_role',
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Dynamic helper to generate text form fields with proper design tokens.
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelKey,
    String? Function(String?)? validator,
    bool enabled = true,
    bool forceLtr = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.appState.translate(labelKey),
          style: AppTypography.labelXs(context, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: enabled ? 1.0 : 0.65,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            validator: validator,
            textDirection: forceLtr ? TextDirection.ltr : null,
            style: AppTypography.bodyLg(
              context,
              color: AppColors.textPrimary,
            ).copyWith(fontFamily: forceLtr ? 'Outfit' : null),
            textAlign: forceLtr ? TextAlign.left : TextAlign.start,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceLow,
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.danger, width: 1.5),
              ),
              errorStyle: AppTypography.bodySm(
                context,
                color: AppColors.danger,
              ),
              prefixIcon: enabled
                  ? null
                  : Icon(
                      Icons.lock_outline,
                      color: AppColors.textTertiary,
                      size: 18,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Footer Action buttons (Save and Cancel) with premium scaling transitions.
  Widget _buildActionButtons({required bool stackButtons}) {
    final saveButton = _ScaleOnTapButton(
      onTap: _isSaving ? null : _saveProfile,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.appState.translate('save_profile'),
                  style: AppTypography.bodyLg(
                    context,
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );

    final cancelButton = _ScaleOnTapButton(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
          color: AppColors.surface,
        ),
        child: Text(
          widget.appState.translate('cancel'),
          style: AppTypography.bodyLg(
            context,
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );

    if (stackButtons) {
      return Column(
        children: [saveButton, const SizedBox(height: 12), cancelButton],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(child: cancelButton),
          const SizedBox(width: 16),
          Expanded(child: saveButton),
        ],
      );
    }
  }
}

/// A button that performs a 2% scaling down animation when tapped to feel premium.
class _ScaleOnTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleOnTapButton({required this.child, required this.onTap});

  @override
  State<_ScaleOnTapButton> createState() => _ScaleOnTapButtonState();
}

class _ScaleOnTapButtonState extends State<_ScaleOnTapButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() {
            _scale = 0.98;
          });
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() {
            _scale = 1.0;
          });
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          setState(() {
            _scale = 1.0;
          });
        }
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(_scale, _scale, 1.0),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
