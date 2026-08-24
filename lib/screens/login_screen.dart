import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_clearError);
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submit() async {
    _clearError();
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa tu correo electrónico.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Por favor ingresa un correo electrónico válido.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa tu contraseña.');
      return;
    }

    if (_isRegisterMode) {
      if (name.isEmpty) {
        setState(() => _errorMessage = 'Por favor ingresa tu nombre completo.');
        return;
      }
      if (password.length < 6) {
        setState(() => _errorMessage = 'La contraseña debe tener al menos 6 caracteres.');
        return;
      }
      if (password != confirmPassword) {
        setState(() => _errorMessage = 'Las contraseñas no coinciden.');
        return;
      }
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;

    if (_isRegisterMode) {
      success = await authProvider.registerUser(
        name: name,
        email: email,
        password: password,
      );
    } else {
      success = await authProvider.loginUser(
        email: email,
        password: password,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = authProvider.error ?? 'Ocurrió un error. Intenta nuevamente.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // App Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              CupertinoIcons.music_note_2,
                              size: 36,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Groovy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    _isRegisterMode
                        ? 'Crea tu cuenta de usuario'
                        : 'Inicia sesión con tu cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? AppTheme.darkSecondaryText
                          : AppTheme.lightSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Native Cupertino Sliding Segmented Control
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<bool>(
                      groupValue: _isRegisterMode,
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5EA),
                      thumbColor: isDark ? const Color(0xFF333333) : Colors.white,
                      children: {
                        false: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: !_isRegisterMode ? FontWeight.bold : FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        true: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _isRegisterMode ? FontWeight.bold : FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null && val != _isRegisterMode) {
                          setState(() {
                            _isRegisterMode = val;
                            _errorMessage = null;
                          });
                          HapticFeedback.selectionClick();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Grouped iOS Card Form
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.darkDivider.withValues(alpha: 0.3) : AppTheme.lightDivider,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_isRegisterMode) ...[
                              _buildInputRow(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                icon: CupertinoIcons.person,
                                placeholder: 'Nombre completo',
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _emailFocusNode.requestFocus(),
                              ),
                              Divider(height: 1, thickness: 0.5, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                            ],
                            _buildInputRow(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              icon: CupertinoIcons.mail,
                              placeholder: 'Correo electrónico',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            ),
                            Divider(height: 1, thickness: 0.5, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                            _buildInputRow(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              icon: CupertinoIcons.lock,
                              placeholder: 'Contraseña',
                              obscureText: _obscurePassword,
                              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                              textInputAction: _isRegisterMode ? TextInputAction.next : TextInputAction.done,
                              onSubmitted: (_) => _isRegisterMode ? _confirmPasswordFocusNode.requestFocus() : _submit(),
                            ),
                            if (_isRegisterMode) ...[
                              Divider(height: 1, thickness: 0.5, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                              _buildInputRow(
                                controller: _confirmPasswordController,
                                focusNode: _confirmPasswordFocusNode,
                                icon: CupertinoIcons.lock_shield,
                                placeholder: 'Confirmar contraseña',
                                obscureText: _obscureConfirmPassword,
                                onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Forgot Password Button (only in login mode)
                  if (!_isRegisterMode) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          final updatedEmail = await Navigator.of(context).push<String>(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(
                                initialEmail: _emailController.text.trim(),
                              ),
                            ),
                          );
                          if (updatedEmail != null && updatedEmail.isNotEmpty && mounted) {
                            setState(() {
                              _emailController.text = updatedEmail;
                              _passwordController.clear();
                              _errorMessage = null;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE50914) : primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              _isRegisterMode ? 'Crear Cuenta' : 'Iniciar Sesión',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),


                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String placeholder,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? AppTheme.darkTertiaryText
                      : AppTheme.lightSecondaryText.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              icon: Icon(
                obscureText ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                size: 18,
                color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
              ),
              onPressed: onToggleObscure,
            ),
        ],
      ),
    );
  }
}
