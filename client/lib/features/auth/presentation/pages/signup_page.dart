import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupPage extends StatefulWidget {
  final AppStateNotifier appState;

  const SignupPage({super.key, required this.appState});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  double _mouseX = 0.0;
  double _mouseY = 0.0;
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

  void _handleGoogleSignup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isAuthenticating = true;
    });

    try {
      await widget.appState.signInWithGoogle();
      // On success, state updates will trigger rebuild in MyApp.
      // Since LoginPage pushed SignupPage on stack, we pop back to Login
      // which will then be dismissed by Auth Guard.
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.locale == 'he'
                ? 'שגיאה בהרשמה: $e'
                : 'Signup failed: $e',
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

            // Grid Paper Background overlay
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

            // Floating Header Bar (Language toggle)
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

            // Main Content Area
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
                          // App Icon Header
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.glassBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.glassBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.visibility,
                              color: AppColors.secondary,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Header Text
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
                            widget.appState.translate('create_account_desc'),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySm(context,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 32),

                          // Glassmorphic Card containing only Google Sign Up
                          GlassmorphicCard(
                            borderRadius: 32.0,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    widget.appState.translate('create_account_title'),
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
                                      : OutlinedButton(
                                          onPressed: () =>
                                              _handleGoogleSignup(context),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                                color: AppColors.glassBorder,
                                                width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            backgroundColor: AppColors.glassBg,
                                          ),
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
                                                        color: Colors.blue),
                                              ),
                                              const SizedBox(width: 12),
                                              Flexible(
                                                child: Text(
                                                  widget.appState.translate(
                                                      'sign_up_google'),
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
                                        ),
                                  const SizedBox(height: 24),

                                  // SSL Divider
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

                                  // Disclaimer
                                  Text(
                                    widget.appState.translate('terms_disclaimer'),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.labelXs(context,
                                            color: AppColors.textTertiary)
                                        .copyWith(
                                      fontSize: 10,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Footer Navigate Back to Login
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.appState.translate(
                                    'already_have_account'),
                                style: AppTypography.bodySm(context,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Text(
                                    widget.appState.translate('login_label'),
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
