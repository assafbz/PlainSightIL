import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';

class LoginPage extends StatefulWidget {
  final AppStateNotifier appState;

  const LoginPage({super.key, required this.appState});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // Mouse coordinates for interactive orbs
  double _mouseX = 0.0;
  double _mouseY = 0.0;
  bool _isHoveringLogo = false;
  bool _isAuthenticating = false;
  bool _isLoginMode = true; // State to toggle between Login and Signup

  late AnimationController _fadeController;
  late AnimationController _pulseController; // Auto-pulse background orbs

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    final isWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    if (!AppStateNotifier.isTesting && !isWidgetTest) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleGoogleAuth(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isAuthenticating = true;
    });

    try {
      await widget.appState.signInWithGoogle();
      // On success, state updates will trigger rebuild in MyApp
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.locale == 'he'
                ? (_isLoginMode ? 'שגיאה בהתחברות: $e' : 'שגיאה בהרשמה: $e')
                : (_isLoginMode
                      ? 'Authentication failed: $e'
                      : 'Signup failed: $e'),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mouseX = event.position.dx;
            _mouseY = event.position.dy;
          });
        },
        child: Stack(
          children: [
            // Ambient Orbs with dual auto-pulsing and mouse interaction
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseVal = _pulseController.value;
                return Stack(
                  children: [
                    // Teal Orb (Top-Left quadrant)
                    Positioned(
                      top: -120 + (_mouseY / 25) + (pulseVal * 30),
                      left: -120 + (_mouseX / 25) + (pulseVal * 30),
                      child: Container(
                        width: 420 + (pulseVal * 40),
                        height: 420 + (pulseVal * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    // Violet Orb (Bottom-Right quadrant)
                    Positioned(
                      bottom: -120 - (_mouseY / 25) - (pulseVal * 30),
                      right: -120 - (_mouseX / 25) - (pulseVal * 30),
                      child: Container(
                        width: 420 + (pulseVal * 40),
                        height: 420 + (pulseVal * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary.withValues(alpha: 0.14),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Grid Pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: GridPaper(
                  color: AppColors.primaryContainer,
                  divisions: 1,
                  subdivisions: 1,
                  interval: 48,
                  child: Container(),
                ),
              ),
            ),

            // Floating Header Bar (Language switch & Theme switch)
            Positioned(
              top: 24,
              right: isRtl ? null : 24,
              left: isRtl ? 24 : null,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Theme Switcher button
                    GestureDetector(
                      onTap: () => widget.appState.toggleTheme(),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.glassBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Icon(
                            widget.appState.isDarkMode
                                ? Icons.wb_sunny_outlined
                                : Icons.mode_night_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Language Switcher button
                    GestureDetector(
                      onTap: () => widget.appState.toggleLocale(),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Text(
                            widget.appState.translate('toggle_lang'),
                            style: AppTypography.labelXs(
                              context,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Canvas
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          // Interactive Brand Logo
                          MouseRegion(
                            onEnter: (_) =>
                                setState(() => _isHoveringLogo = true),
                            onExit: (_) =>
                                setState(() => _isHoveringLogo = false),
                            cursor: SystemMouseCursors.click,
                            child: AnimatedRotation(
                              turns: _isHoveringLogo ? (6 / 360) : 0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_isLoginMode
                                                  ? AppColors.primary
                                                  : AppColors.secondary)
                                              .withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    'assets/images/plainsight_logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Brand Headers
                          Text(
                            widget.appState.translate('app_title'),
                            style:
                                AppTypography.headlineLg(
                                  context,
                                  color: AppColors.textPrimary,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: Text(
                              _isLoginMode
                                  ? widget.appState.translate('login_desc')
                                  : widget.appState.translate(
                                      'create_account_desc',
                                    ),
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySm(
                                context,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Glassmorphic Unified Auth Card
                          GlassmorphicCard(
                            borderRadius: 32.0,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. Tab Segment Switcher
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLow.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: AppColors.glassBorder,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Animated Sliding Capsule
                                        AnimatedAlign(
                                          alignment: _isLoginMode
                                              ? (isRtl
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft)
                                              : (isRtl
                                                    ? Alignment.centerLeft
                                                    : Alignment.centerRight),
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          child: FractionallySizedBox(
                                            widthFactor: 0.5,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors
                                                    .primaryContainer
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.2),
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Tab Buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _isLoginMode = true;
                                                  });
                                                },
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                  child: Center(
                                                    child: Text(
                                                      widget.appState.translate(
                                                        'login_label',
                                                      ),
                                                      style:
                                                          AppTypography.labelXs(
                                                            context,
                                                            color: _isLoginMode
                                                                ? AppColors
                                                                      .primary
                                                                : AppColors
                                                                      .textSecondary,
                                                          ).copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _isLoginMode = false;
                                                  });
                                                },
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                  child: Center(
                                                    child: Text(
                                                      widget.appState.translate(
                                                        'signup_label',
                                                      ),
                                                      style:
                                                          AppTypography.labelXs(
                                                            context,
                                                            color: !_isLoginMode
                                                                ? AppColors
                                                                      .primary
                                                                : AppColors
                                                                      .textSecondary,
                                                          ).copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // 2. Animated Content Area (Cross-fade height transition)
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    layoutBuilder:
                                        (
                                          Widget? currentChild,
                                          List<Widget> previousChildren,
                                        ) {
                                          return Stack(
                                            alignment: Alignment.topCenter,
                                            children: <Widget>[
                                              ...previousChildren,
                                              if (currentChild != null)
                                                currentChild,
                                            ],
                                          );
                                        },
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SizeTransition(
                                          sizeFactor: animation,
                                          axisAlignment: -1.0,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _isLoginMode
                                        ? _buildLoginView(context)
                                        : _buildSignupView(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Guest mode bypass action (Always visible at bottom)
                          GestureDetector(
                            onTap: () {
                              widget.appState.setGuestMode(true);
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style:
                                    AppTypography.bodySm(
                                      context,
                                      color: AppColors.textSecondary,
                                    ).copyWith(
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                child: Text(
                                  widget.appState.translate('continue_guest'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Content Sub-views
  // -------------------------------------------------------------

  Widget _buildLoginView(BuildContext context) {
    return Column(
      key: const ValueKey('login_view_content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.appState.translate('welcome_back'),
          textAlign: TextAlign.center,
          style: AppTypography.headlineMd(
            context,
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          widget.appState.translate('secure_auth'),
          textAlign: TextAlign.center,
          style: AppTypography.labelXs(
            context,
            color: AppColors.textTertiary,
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 32),

        // Google Authentication Button (Login Mode)
        _buildGoogleButton(label: widget.appState.translate('sign_in_google')),
        const SizedBox(height: 24),

        // SSL Badge Divider
        _buildSslDivider(),
        const SizedBox(height: 24),

        // Info Box detailing login advantages
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassGlow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.appState.translate('login_info_text'),
                  style: AppTypography.bodySm(
                    context,
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignupView(BuildContext context) {
    return Column(
      key: const ValueKey('signup_view_content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.appState.translate('create_account_title'),
          textAlign: TextAlign.center,
          style: AppTypography.headlineMd(
            context,
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          widget.appState.translate('secure_auth'),
          textAlign: TextAlign.center,
          style: AppTypography.labelXs(
            context,
            color: AppColors.textTertiary,
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 32),

        // Google Authentication Button (Signup Mode)
        _buildGoogleButton(label: widget.appState.translate('sign_up_google')),
        const SizedBox(height: 24),

        // SSL Badge Divider
        _buildSslDivider(),
        const SizedBox(height: 24),

        // Disclaimer for Terms
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            widget.appState.translate('terms_disclaimer'),
            textAlign: TextAlign.center,
            style: AppTypography.labelXs(
              context,
              color: AppColors.textTertiary,
            ).copyWith(fontSize: 10, height: 1.5),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Custom Reusable Widgets
  // -------------------------------------------------------------

  Widget _buildSslDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.glassBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            widget.appState.translate('ssl_protection'),
            style: AppTypography.labelXs(
              context,
              color: AppColors.textTertiary,
            ).copyWith(fontSize: 10, letterSpacing: 1.0),
          ),
        ),
        Expanded(child: Divider(color: AppColors.glassBorder, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton({required String label}) {
    if (_isAuthenticating) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _AnimatedGlassButton(
      onTap: () => _handleGoogleAuth(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/google_logo.png',
            height: 24,
            width: 24,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.g_mobiledata, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// _AnimatedGlassButton - Premium Animated Tap & Hover Button
// ---------------------------------------------------------------------
class _AnimatedGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedGlassButton({required this.child, required this.onTap});

  @override
  State<_AnimatedGlassButton> createState() => _AnimatedGlassButtonState();
}

class _AnimatedGlassButtonState extends State<_AnimatedGlassButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovering ? AppColors.primary : AppColors.glassBorder,
                width: 1.5,
              ),
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
