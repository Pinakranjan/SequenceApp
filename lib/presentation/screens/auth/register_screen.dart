import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';

/// Registration screen with business code validation.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _businessCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _isValidatingCode = false;

  static const String _logoAsset = 'assets/images/icons/logo.svg';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms & Conditions');
      return;
    }

    // Prompt for business code
    final code = await _showBusinessCodeDialog();
    if (code == null) return; // User cancelled

    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirmation: _confirmPasswordController.text,
      companyCode: code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      _showError(result['message'] ?? 'Registration failed');
    }
  }

  Future<String?> _showBusinessCodeDialog() async {
    _businessCodeController.clear();
    String? validationMessage;
    bool? isValid;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.business, color: AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  const Text('Business Code'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the 10-character business code provided by your organization.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _businessCodeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: 'e.g. ABCD123456',
                      counterText: '${_businessCodeController.text.length}/10',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      setDialogState(() {
                        validationMessage = null;
                        isValid = null;
                      });
                    },
                  ),
                  if (validationMessage != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isValid == true ? Icons.check_circle : Icons.error,
                          size: 16,
                          color:
                              isValid == true
                                  ? AppColors.success
                                  : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            validationMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isValid == true
                                      ? AppColors.success
                                      : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      _isValidatingCode
                          ? null
                          : () async {
                            final code =
                                _businessCodeController.text
                                    .trim()
                                    .toUpperCase();
                            if (code.length != 10) {
                              setDialogState(() {
                                validationMessage =
                                    'Code must be exactly 10 characters.';
                                isValid = false;
                              });
                              return;
                            }

                            setDialogState(() => _isValidatingCode = true);

                            final authService = ref.read(authServiceProvider);
                            final result = await authService
                                .validateBusinessCode(code);

                            setDialogState(() => _isValidatingCode = false);

                            if (result['valid'] == true) {
                              setDialogState(() {
                                validationMessage =
                                    result['message'] ?? 'Code accepted';
                                isValid = true;
                              });
                              // Short delay to show success, then close
                              await Future.delayed(
                                const Duration(milliseconds: 600),
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(code);
                              }
                            } else {
                              setDialogState(() {
                                validationMessage =
                                    result['message'] ?? 'Invalid code';
                                isValid = false;
                              });
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isValidatingCode
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Validate & Continue'),
                ),
              ],
            );
          },
        );
      },
    );
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Terms & Conditions'),
            content: const SingleChildScrollView(
              child: Text(
                'By using the Sequence platform, you agree to the following:\n\n'
                '1. You will use the platform solely for authorized vehicle logistics operations.\n\n'
                '2. You are responsible for maintaining the confidentiality of your account credentials.\n\n'
                '3. All data entered into the system must be accurate and up to date.\n\n'
                '4. The platform is provided "as is" without warranty of any kind.\n\n'
                '5. Your organization\'s administrator may monitor your usage and activity.\n\n'
                '6. Misuse of the platform may result in account suspension.\n\n'
                'For the full terms of service, please contact your organization\'s administrator.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // ── Logo ──
                    Container(
                      width: 64,
                      height: 64,
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
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          _logoAsset,
                          width: 36,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join Sequence to manage your fleet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF666666),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Name ──
                    _buildField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'John Doe',
                      icon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Email ──
                    _buildField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(
                          r'^[^@]+@[^@]+\.[^@]+$',
                        ).hasMatch(v.trim())) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Password ──
                    _buildField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Create a password',
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Confirm Password ──
                    _buildField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Confirm your password',
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed:
                            () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ── Terms Checkbox ──
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged:
                                (v) =>
                                    setState(() => _agreedToTerms = v ?? false),
                            activeColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: RichText(
                              text: TextSpan(
                                text: 'I agree to the ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF555555),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Register Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primaryGreen
                              .withValues(alpha: 0.6),
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
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Already have account ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF888888),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/login');
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
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
    );
  }
}
