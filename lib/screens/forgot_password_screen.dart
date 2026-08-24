import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/email_verification_service.dart';
import '../services/groovy_api_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 0; // 0: Email, 1: OTP, 2: New Password

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  String? _generatedOtp;
  DateTime? _otpGeneratedAt;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // ----------------------------------------------------
  // STEP 1: Send OTP to Email
  // ----------------------------------------------------
  Future<void> _sendCode() async {
    _clearError();
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa tu correo electrónico.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Por favor ingresa un correo electrónico válido.');
      return;
    }

    setState(() {
      _isLoading = true;
      _successMessage = null;
    });
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    // 1. Verify if user exists in database
    final apiService = GroovyApiService();
    final emailExists = await apiService.checkEmailExists(email);

    if (!emailExists) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No existe ninguna cuenta registrada con este correo.';
        });
      }
      return;
    }

    // 2. Generate 6-digit OTP code
    final otp = EmailVerificationService.generateOtp();
    _generatedOtp = otp;
    _otpGeneratedAt = DateTime.now();

    // 3. Send email using SMTP
    final sent = await EmailVerificationService.sendRecoveryEmail(
      recipientEmail: email,
      code: otp,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (sent) {
        setState(() {
          _currentStep = 1;
          _successMessage = 'Código enviado a $email';
        });
        _startResendTimer();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _codeFocusNode.requestFocus();
        });
      } else {
        setState(() {
          _errorMessage = 'No se pudo enviar el correo de verificación. Verifica tu conexión.';
        });
      }
    }
  }

  // ----------------------------------------------------
  // STEP 2: Validate OTP Code
  // ----------------------------------------------------
  void _verifyCode() {
    _clearError();
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa el código de 6 dígitos.');
      return;
    }
    if (code.length < 6) {
      setState(() => _errorMessage = 'El código debe tener 6 dígitos.');
      return;
    }

    if (_generatedOtp == null || code != _generatedOtp) {
      setState(() => _errorMessage = 'El código ingresado es incorrecto.');
      HapticFeedback.heavyImpact();
      return;
    }

    // Check expiration (15 minutes)
    if (_otpGeneratedAt != null &&
        DateTime.now().difference(_otpGeneratedAt!).inMinutes > 15) {
      setState(() => _errorMessage = 'El código ha expirado. Solicita uno nuevo.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 2;
      _errorMessage = null;
      _successMessage = null;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _newPasswordFocusNode.requestFocus();
    });
  }

  // ----------------------------------------------------
  // STEP 3: Change Password
  // ----------------------------------------------------
  Future<void> _updatePassword() async {
    _clearError();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final email = _emailController.text.trim().toLowerCase();

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu nueva contraseña.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final apiService = GroovyApiService();
    final res = await apiService.resetPassword(
      email: email,
      newPassword: newPassword,
      code: _generatedOtp,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        HapticFeedback.heavyImpact();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF1DB954), size: 26),
                SizedBox(width: 10),
                Text('¡Contraseña cambiada!', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: const Text(
              'Tu contraseña se ha actualizado correctamente. Ahora puedes iniciar sesión con tu nueva clave.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).pop(email); // Returns email back to Login
                },
                child: const Text('Iniciar Sesión', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = res.error ?? 'No se pudo actualizar la contraseña. Intenta nuevamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFE50914);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_back,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Recuperar Contraseña',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator Pill
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Paso ${_currentStep + 1} de 3',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        _currentStep == 0
                            ? CupertinoIcons.mail_solid
                            : (_currentStep == 1 ? CupertinoIcons.shield_lefthalf_fill : CupertinoIcons.lock_fill),
                        size: 30,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title & Description
                  Text(
                    _currentStep == 0
                        ? 'Ingresa tu correo'
                        : (_currentStep == 1 ? 'Verifica el código' : 'Nueva contraseña'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == 0
                        ? 'Te enviaremos un código de seguridad de 6 dígitos para validar tu identidad.'
                        : (_currentStep == 1
                            ? 'Introduce el código de 6 dígitos que enviamos a tu bandeja de entrada.'
                            : 'Crea una contraseña segura para acceder a tu cuenta.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Success message banner
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF1DB954), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Color(0xFF1DB954), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error message banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle_fill, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Container
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.darkDivider.withValues(alpha: 0.3) : AppTheme.lightDivider,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          if (_currentStep == 0) ...[
                            _buildInputRow(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              icon: CupertinoIcons.mail,
                              placeholder: 'Correo electrónico',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _sendCode(),
                            ),
                          ] else if (_currentStep == 1) ...[
                            _buildInputRow(
                              controller: _codeController,
                              focusNode: _codeFocusNode,
                              icon: CupertinoIcons.number,
                              placeholder: 'Código de 6 dígitos (ej: 481923)',
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 6,
                              onSubmitted: (_) => _verifyCode(),
                            ),
                          ] else if (_currentStep == 2) ...[
                            _buildInputRow(
                              controller: _newPasswordController,
                              focusNode: _newPasswordFocusNode,
                              icon: CupertinoIcons.lock,
                              placeholder: 'Nueva contraseña',
                              obscureText: _obscureNewPassword,
                              onToggleObscure: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                            ),
                            Divider(height: 1, thickness: 0.5, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                            _buildInputRow(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              icon: CupertinoIcons.lock_shield,
                              placeholder: 'Confirmar nueva contraseña',
                              obscureText: _obscureConfirmPassword,
                              onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _updatePassword(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep == 0
                              ? _sendCode
                              : (_currentStep == 1 ? _verifyCode : _updatePassword)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              _currentStep == 0
                                  ? 'Enviar Código'
                                  : (_currentStep == 1 ? 'Validar Código' : 'Cambiar Contraseña'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  // Resend code option in Step 1
                  if (_currentStep == 1) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _resendCountdown == 0 ? _sendCode : null,
                        child: Text(
                          _resendCountdown > 0
                              ? 'Reenviar código en ${_resendCountdown}s'
                              : '¿No recibiste el código? Reenviar',
                          style: TextStyle(
                            color: _resendCountdown > 0
                                ? (isDark ? Colors.white38 : Colors.black38)
                                : primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
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
    int? maxLength,
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
              maxLength: maxLength,
              buildCounter: maxLength != null ? (_, {required currentLength, required isFocused, maxLength}) => null : null,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTertiaryText : AppTheme.lightSecondaryText.withValues(alpha: 0.7),
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
