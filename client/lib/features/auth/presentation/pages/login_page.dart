import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final AppStateNotifier appState;

  const LoginPage({super.key, required this.appState});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  double _mouseX = 0.0;
  double _mouseY = 0.0;
  bool _isHoveringLogo = false;
  bool _isAuthenticating = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handleGoogleLogin(BuildContext context) async {
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
                ? 'שגיאה בהתחברות: $e'
                : 'Authentication failed: $e',
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
            // Ambient Orbs
            Positioned(
              top: -150 + (_mouseY / 20),
              left: -150 + (_mouseX / 20),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -150 - (_mouseY / 20),
              right: -150 - (_mouseX / 20),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
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

            // Language Switcher Floating
            Positioned(
              top: 24,
              right: isRtl ? null : 24,
              left: isRtl ? 24 : null,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => widget.appState.toggleLocale(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        widget.appState.translate('toggle_lang'),
                        style: AppTypography.labelXs(context,
                            color: AppColors.primary),
                      ),
                    ),
                  ),
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
                          // Rotating Brand Logo
                          MouseRegion(
                            onEnter: (_) => setState(() => _isHoveringLogo = true),
                            onExit: (_) => setState(() => _isHoveringLogo = false),
                            cursor: SystemMouseCursors.click,
                            child: AnimatedRotation(
                              turns: _isHoveringLogo ? 0.0 : (3 / 360),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.glassBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.glassBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.visibility,
                                  color: AppColors.primary,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Brand Headers
                          Text(
                            'PlainSight IL',
                            style: AppTypography.headlineLg(context,
                                    color: AppColors.textPrimary)
                                .copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.appState.translate('login_desc'),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySm(context,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 32),

                          // Glassmorphic Login Card
                          GlassmorphicCard(
                            borderRadius: 32.0,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    widget.appState.translate('welcome_back'),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.headlineMd(context,
                                        color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.appState.translate('secure_auth'),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.labelXs(context,
                                            color: AppColors.textTertiary)
                                        .copyWith(letterSpacing: 1.5),
                                  ),
                                  const SizedBox(height: 32),

                                  // Google Button
                                  _isAuthenticating
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : Material(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: InkWell(
                                            onTap: () =>
                                                _handleGoogleLogin(context),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              height: 52,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Image.network(
                                                    'https://www.gstatic.com/images/branding/product/1x/glogo_32dp.png',
                                                    height: 24,
                                                    width: 24,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        const Icon(
                                                            Icons.g_mobiledata,
                                                            color:
                                                                Colors.blue),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Flexible(
                                                    child: Text(
                                                      widget.appState.translate(
                                                          'sign_in_google'),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            const Color(0xFF1F1F1F),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                  const SizedBox(height: 24),

                                  // SSL Badge Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: AppColors.glassBorder,
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0),
                                        child: Text(
                                          widget.appState.translate(
                                              'ssl_protection'),
                                          style: AppTypography.labelXs(context,
                                                  color: AppColors.textTertiary)
                                              .copyWith(fontSize: 10),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: AppColors.glassBorder,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Info Box
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.glassGlow,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            AppColors.primary.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: AppColors.primary,
                                            size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            widget.appState.translate(
                                                'login_info_text'),
                                            style: AppTypography.bodySm(context,
                                                    color: AppColors
                                                        .textSecondary)
                                                .copyWith(
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Footer Navigation Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.appState.translate(
                                    'dont_have_account'),
                                style: AppTypography.bodySm(context,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder<void>(
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          SignupPage(appState: widget.appState),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Text(
                                    widget.appState.translate('signup_label'),
                                    style: AppTypography.bodySm(context,
                                            color: AppColors.primary)
                                        .copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Guest mode bypass action
                          GestureDetector(
                            onTap: () {
                              widget.appState.setGuestMode(true);
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                widget.appState.translate('continue_guest'),
                                style: AppTypography.bodySm(context,
                                        color: AppColors.textTertiary)
                                    .copyWith(
                                  decoration: TextDecoration.underline,
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
}
