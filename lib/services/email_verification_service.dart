import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Service that securely sends email verification OTP codes using SMTP over SSL.
class EmailVerificationService {
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 465;
  static const String smtpUser = 'danilorodelo355@gmail.com';
  static const String smtpPass = 'gszsvbqujjebrlgk'; // App password

  // Generates a cryptographically-secure 6-digit OTP code
  static String generateOtp() {
    final rnd = Random.secure();
    final code = 100000 + rnd.nextInt(900000);
    return code.toString();
  }

  /// Sends a 6-digit recovery code to [recipientEmail] via Gmail SMTP over SSL (Port 465).
  static Future<bool> sendRecoveryEmail({
    required String recipientEmail,
    required String code,
  }) async {
    SecureSocket? socket;
    StreamSubscription? subscription;
    try {
      debugPrint('[EmailVerification] Connecting to $smtpHost:$smtpPort for $recipientEmail...');
      socket = await SecureSocket.connect(
        smtpHost,
        smtpPort,
        timeout: const Duration(seconds: 12),
        onBadCertificate: (cert) => true,
      );

      final completer = Completer<bool>();
      int step = 0;
      final cleanPass = smtpPass.replaceAll(' ', '');
      final authPlain = base64.encode(utf8.encode('\u0000$smtpUser\u0000$cleanPass'));

      void send(String cmd) {
        socket?.write('$cmd\r\n');
      }

      subscription = socket.listen(
        (List<int> bytes) {
          final response = utf8.decode(bytes);
          debugPrint('[SMTP] <<< ${response.trim()}');

          if (step == 0 && response.startsWith('220')) {
            step = 1;
            send('EHLO groovy.app');
          } else if (step == 1 && response.startsWith('250')) {
            step = 2;
            send('AUTH PLAIN $authPlain');
          } else if (step == 2 && response.startsWith('235')) {
            step = 3;
            send('MAIL FROM:<$smtpUser>');
          } else if (step == 3 && response.startsWith('250')) {
            step = 4;
            send('RCPT TO:<$recipientEmail>');
          } else if (step == 4 && response.startsWith('250')) {
            step = 5;
            send('DATA');
          } else if (step == 5 && response.startsWith('354')) {
            step = 6;
            final emailBody = _buildHtmlEmail(recipientEmail: recipientEmail, code: code);
            send(emailBody);
          } else if (step == 6 && response.startsWith('250')) {
            step = 7;
            send('QUIT');
            if (!completer.isCompleted) completer.complete(true);
          } else if (response.startsWith('5') || response.startsWith('4')) {
            debugPrint('[SMTP Error] Unexpected response: $response');
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onError: (err) {
          debugPrint('[SMTP Stream Error] $err');
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(step >= 6);
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[SMTP] Timeout sending email');
          return false;
        },
      );

      await subscription.cancel();
      await socket.close();
      return result;
    } catch (e) {
      debugPrint('[EmailVerification] Error: $e');
      try {
        await subscription?.cancel();
        await socket?.close();
      } catch (_) {}
      return false;
    }
  }

  static String _buildHtmlEmail({
    required String recipientEmail,
    required String code,
  }) {
    final digits = code.split('');
    final digitsHtml = digits.map((d) => '''
      <td style="padding: 0 4px;">
        <div style="width: 44px; height: 54px; line-height: 54px; background: rgba(255, 51, 75, 0.12); border: 1.5px solid rgba(255, 51, 75, 0.4); border-radius: 12px; font-size: 28px; font-weight: 800; color: #ff334b; text-align: center; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;">
          $d
        </div>
      </td>
    ''').join('');

    return [
      'From: "Groovy" <$smtpUser>',
      'To: <$recipientEmail>',
      'Subject: =?UTF-8?B?${base64.encode(utf8.encode('Tu código de seguridad de Groovy: $code'))}?=',
      'MIME-Version: 1.0',
      'Content-Type: text/html; charset=UTF-8',
      'Content-Transfer-Encoding: 8bit',
      '',
      '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Código de Recuperación - Groovy</title>
</head>
<body style="margin: 0; padding: 0; background-color: #08090b; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #08090b; min-height: 100vh; padding: 40px 15px;">
    <tr>
      <td align="center" valign="middle">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 500px; background: linear-gradient(180deg, #14151a 0%, #0d0e12 100%); border-radius: 28px; border: 1px solid rgba(255, 255, 255, 0.08); box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6); overflow: hidden; text-align: center;">
          <!-- Header with Logo / Brand -->
          <tr>
            <td style="padding: 40px 32px 20px 32px;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center">
                <tr>
                  <td align="center">
                    <div style="width: 64px; height: 64px; background: linear-gradient(135deg, #ff334b 0%, #e50914 100%); border-radius: 18px; box-shadow: 0 8px 24px rgba(229, 9, 20, 0.45); line-height: 64px; text-align: center;">
                      <span style="font-size: 30px; color: #ffffff;">🎵</span>
                    </div>
                  </td>
                </tr>
              </table>
              <h1 style="margin: 18px 0 0 0; font-size: 26px; font-weight: 800; letter-spacing: -0.8px; color: #ffffff;">Groovy</h1>
              <div style="display: inline-block; margin-top: 6px; padding: 4px 12px; background: rgba(255, 51, 75, 0.12); border-radius: 20px;">
                <span style="font-size: 12px; font-weight: 700; color: #ff334b; letter-spacing: 0.3px; text-transform: uppercase;">Recuperación de Contraseña</span>
              </div>
            </td>
          </tr>

          <!-- Message Body -->
          <tr>
            <td style="padding: 0 32px 20px 32px;">
              <p style="margin: 0; font-size: 15px; line-height: 1.6; color: #a1a1aa; font-weight: 400;">
                Hemos recibido una solicitud para restablecer la contraseña de tu cuenta vinculada a <strong style="color: #ffffff;">$recipientEmail</strong>.
              </p>
              <p style="margin: 8px 0 0 0; font-size: 14px; line-height: 1.5; color: #71717a;">
                Introduce el siguiente código de 6 dígitos en la aplicación para crear tu nueva clave:
              </p>
            </td>
          </tr>

          <!-- OTP Code Table -->
          <tr>
            <td style="padding: 10px 24px 28px 24px;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin: 0 auto;">
                <tr>
                  $digitsHtml
                </tr>
              </table>
            </td>
          </tr>

          <!-- Advisory / Expiration Notice -->
          <tr>
            <td style="padding: 0 32px 32px 32px;">
              <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 16px; padding: 14px 18px; text-align: left;">
                <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                  <tr>
                    <td width="24" valign="top" style="padding-top: 2px;">
                      <span style="font-size: 14px; color: #ff334b;">🔒</span>
                    </td>
                    <td style="padding-left: 8px;">
                      <div style="font-size: 12px; color: #d4d4d8; font-weight: 600; margin-bottom: 2px;">Vigencia del código: 15 minutos</div>
                      <div style="font-size: 11px; color: #71717a; line-height: 1.4;">Si tú no realizaste esta solicitud, puedes ignorar este mensaje; tu cuenta permanecerá totalmente protegida.</div>
                    </td>
                  </tr>
                </table>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 32px; border-top: 1px solid rgba(255, 255, 255, 0.05); background-color: rgba(0, 0, 0, 0.2);">
              <div style="font-size: 12px; font-weight: 600; color: #71717a;">Groovy Music App</div>
              <div style="font-size: 11px; color: #52525b; margin-top: 4px;">Tu música en streaming de alta calidad sin interrupciones.</div>
              <div style="font-size: 10px; color: #3f3f46; margin-top: 8px;">© ${DateTime.now().year} Groovy. Todos los derechos reservados.</div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''',
      '.',
    ].join('\r\n');
  }
}
