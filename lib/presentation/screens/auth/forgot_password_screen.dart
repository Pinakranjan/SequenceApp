import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';

/// Forgot password screen — sends reset code email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  static const String _logoAsset = 'assets/images/icons/logo.svg';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.forgotPassword(
      _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() => _emailSent = true);
    } else {
      _showError(result['message'] ?? 'An error occurred');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _emailSent ? _buildSuccessView(theme) : _buildForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Logo ──
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                _logoAsset,
                width: 38,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Forgot Password',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a password reset code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 32),

          // ── Email Field ──
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 28),

          // ── Submit Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryGreen.withValues(
                  alpha: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        'Send Reset Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Back Links ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Login'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF888888),
                ),
              ),
              TextButton(
                onPressed:
                    () =>
                        Navigator.of(context).pushReplacementNamed('/landing'),
                child: Text(
                  'Back Home',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check Your Email',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We\'ve sent a password reset code to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF666666),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                () => Navigator.of(context).pushReplacementNamed('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () {
            setState(() => _emailSent = false);
          },
          child: const Text('Didn\'t receive it? Try again'),
        ),
      ],
    );
  }
}
