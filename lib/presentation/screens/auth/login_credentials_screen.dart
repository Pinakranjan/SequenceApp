import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';

/// Login Step 2: Credentials entry with PIN/Password toggle.
///
/// Receives via route arguments:
///   - 'email': String
///   - 'user': Map with name, email, role, photo_url, has_pin_enabled
class LoginCredentialsScreen extends ConsumerStatefulWidget {
  const LoginCredentialsScreen({super.key});

  @override
  ConsumerState<LoginCredentialsScreen> createState() =>
      _LoginCredentialsScreenState();
}

class _LoginCredentialsScreenState
    extends ConsumerState<LoginCredentialsScreen> {
  late String _email;
  late Map<String, dynamic> _user;
  late bool _hasPinEnabled;

  String _authMethod = 'pin'; // 'pin' or 'password'
  bool _isLoading = false;
  bool _obscurePassword = true;

  // PIN validation visual feedback: 'idle', 'success', 'error'
  String _pinValidationState = 'idle';

  final _passwordController = TextEditingController();
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _email = args['email'] as String;
      _user = args['user'] as Map<String, dynamic>;
      _hasPinEnabled = _user['has_pin_enabled'] == true;
      _authMethod = _hasPinEnabled ? 'pin' : 'password';
      _didInit = true;

      // Auto-focus first PIN or password
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_hasPinEnabled) {
          _pinFocusNodes[0].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _pinValue => _pinControllers.map((c) => c.text).join();

  Future<void> _handleLogin() async {
    if (_authMethod == 'password' && _passwordController.text.trim().isEmpty) {
      _showError('Please enter your password.');
      return;
    }
    if (_authMethod == 'pin' && _pinValue.length < 4) {
      _showError('Please enter the complete 4-digit PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
      if (_authMethod == 'pin') {
        _pinValidationState = 'idle';
      }
    });

    final authService = ref.read(authServiceProvider);

    final result = await authService.login(
      email: _email,
      authMethod: _authMethod,
      password: _authMethod == 'password' ? _passwordController.text : null,
      pin: _authMethod == 'pin' ? _pinValue : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (_authMethod == 'pin') {
        setState(() {
          _pinValidationState = 'success';
          _isLoading = false;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
      }

      // Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      final key = 'onboarding_completed_${AppConfig.appVersion}';
      final onboardingDone = prefs.getBool(key) ?? false;
      if (!mounted) return;

      if (!onboardingDone) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/onboarding', (_) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } else {
      _showError(result['message'] ?? 'Login failed');
      // Clear PIN on error
      if (_authMethod == 'pin') {
        setState(() {
          _pinValidationState = 'error';
        });
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() {
          _pinValidationState = 'idle';
        });
        for (final c in _pinControllers) {
          c.clear();
        }
        _pinFocusNodes[0].requestFocus();
      }
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
    final isOffline = ref.watch(isOfflineProvider);

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isOffline)
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: Lottie.asset(
                        'assets/lottie/lottie_offline_resized.json',
                        repeat: true,
                      ),
                    ),
                  if (isOffline) const SizedBox(height: 8),

                  // ── User Avatar ──
                  _buildUserPreview(theme),

                  const SizedBox(height: 24),

                  // ── Auth Method Toggle (only if PIN enabled) ──
                  if (_hasPinEnabled) ...[
                    _buildMethodToggle(theme),
                    const SizedBox(height: 24),
                  ],

                  // ── Credentials Input ──
                  if (_authMethod == 'pin')
                    _buildPinInput(theme)
                  else
                    _buildPasswordInput(theme),

                  const SizedBox(height: 28),

                  // ── Login Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
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
                                'Log In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Bottom Links ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF888888),
                        ),
                        child: const Text('Back to Home'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // go back to email step
                        },
                        child: Text(
                          'Use different account',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserPreview(ThemeData theme) {
    final name = _user['name'] ?? 'User';
    final email = _user['email'] ?? _email;
    final role = (_user['role'] ?? 'user').toString();
    final photoUrl = _user['photo_url'] as String?;

    String roleLabel;
    Color roleBadgeColor;
    switch (role.toLowerCase()) {
      case 'super admin':
        roleLabel = 'Super Admin';
        roleBadgeColor = AppColors.error;
        break;
      case 'admin':
        roleLabel = 'Admin';
        roleBadgeColor = AppColors.success;
        break;
      default:
        roleLabel = 'User';
        roleBadgeColor = const Color(0xFF8C57D1);
    }

    return Column(
      children: [
        // Avatar
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child:
                photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.2,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                    )
                    : Container(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: AppColors.primaryGreen,
                      ),
                    ),
          ),
        ),

        const SizedBox(height: 14),

        // Name + Role badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleBadgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                roleLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          email,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF888888),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Enter Your Credentials',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please enter your ${_hasPinEnabled ? "PIN or password" : "password"} to continue',
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodToggle(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _toggleButton('PIN', 'pin', theme),
        const SizedBox(width: 10),
        _toggleButton('Password', 'password', theme),
      ],
    );
  }

  Widget _toggleButton(String label, String method, ThemeData theme) {
    final isActive = _authMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() => _authMethod = method);
        if (method == 'pin') {
          _pinFocusNodes[0].requestFocus();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primaryGreen : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF555555),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPinInput(ThemeData theme) {
    const successBorder = Color(0xFF10B981);
    const successFill = Color(0xFFD1FAE5);
    const successText = Color(0xFF065F46);
    const errorBorder = Color(0xFFEF4444);
    const errorFill = Color(0xFFFEE2E2);
    const errorText = Color(0xFF991B1B);
    const idleBorder = Color(0xFFD1D5DB);

    Color borderColor;
    Color fillColor;
    Color textColor;

    switch (_pinValidationState) {
      case 'success':
        borderColor = successBorder;
        fillColor = successFill;
        textColor = successText;
        break;
      case 'error':
        borderColor = errorBorder;
        fillColor = errorFill;
        textColor = errorText;
        break;
      default:
        borderColor = idleBorder;
        fillColor = Colors.white;
        textColor = const Color(0xFF1A1A1A);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 55,
          height: 62,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: fillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      _pinValidationState == 'idle'
                          ? AppColors.primaryGreen
                          : borderColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (value) {
              if (_pinValidationState != 'idle') {
                setState(() => _pinValidationState = 'idle');
              }
              if (value.length == 1 && index < 3) {
                _pinFocusNodes[index + 1].requestFocus();
              }
              // Auto-submit when all 4 digits entered
              if (index == 3 && _pinValue.length == 4) {
                Future.delayed(const Duration(milliseconds: 300), _handleLogin);
              }
            },
            onTap: () {
              _pinControllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _pinControllers[index].text.length,
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildPasswordInput(ThemeData theme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
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
