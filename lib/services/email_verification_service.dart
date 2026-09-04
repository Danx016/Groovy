import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Servicio para el envío seguro de códigos de verificación OTP por correo electrónico.
/// Soporta tanto **Oracle Cloud Infrastructure (OCI) Email Delivery** (STARTTLS / Puerto 587)
/// como **Gmail SMTP** como respaldo (Fallback).
class EmailVerificationService {
  // ===========================================================================
  // CONFIGURACIÓN DE ORACLE CLOUD EMAIL DELIVERY (OCI)
  // ===========================================================================
  // 1. Host SMTP: smtp.email.<region>.oci.oraclecloud.com
  //    Para la región de Colombia (Bogotá): smtp.email.sa-bogota-1.oci.oraclecloud.com
  //    Otras comunes: sa-santiago-1, us-ashburn-1, us-phoenix-1, etc.
  static const String ociSmtpHost = 'smtp.email.sa-bogota-1.oci.oraclecloud.com';
  static const int ociSmtpPort = 587; // Puerto estándar para OCI con STARTTLS

  // 2. Usuario SMTP generado en la consola de Oracle Cloud:
  //    (Perfil -> Configuración de usuario -> Credenciales SMTP -> Generar)
  //    Tiene un formato similar a: ocid1.user.oc1..aaaaaaa...
  static const String ociSmtpUser = '';

  // 3. Contraseña SMTP generada en Oracle Cloud (no es tu clave personal de Oracle):
  static const String ociSmtpPass = '';

  // 4. Remitente Aprobado (Approved Sender) configurado en OCI Email Delivery:
  //    Ej: 'noreply@tudominio.com' o el correo verificado en la consola.
  static const String ociSenderEmail = 'noreply@groovy.app';

  // ===========================================================================
  // CONFIGURACIÓN DE RESPALDO (GMAIL SMTP)
  // ===========================================================================
  static const String gmailUser = 'danilorodelo355@gmail.com';
  static const String gmailPass = 'gszsvbqujjebrlgk'; // App password de Google

  /// Genera un código OTP criptográficamente seguro de 6 dígitos
  static String generateOtp() {
    final rnd = Random.secure();
    final code = 100000 + rnd.nextInt(900000);
    return code.toString();
  }

  /// Envía el código de recuperación por correo electrónico.
  /// Intenta primero con Oracle Cloud Email Delivery (si está configurado)
  /// y recurre automáticamente a Gmail en caso de error o si aún no hay credenciales OCI.
  static Future<bool> sendRecoveryEmail({
    required String recipientEmail,
    required String code,
  }) async {
    final cleanRecipient = recipientEmail.trim().toLowerCase();
    final htmlContent = _buildHtmlEmail(recipientEmail: cleanRecipient, code: code);

    // 1. Intentar con Oracle Cloud Email Delivery si las credenciales están configuradas
    final hasOciConfig = ociSmtpUser.trim().isNotEmpty && ociSmtpPass.trim().isNotEmpty;
    if (hasOciConfig) {
      try {
        debugPrint('[EmailVerification] Intentando envío vía Oracle Cloud Email Delivery ($ociSmtpHost:$ociSmtpPort)...');
        final ociServer = SmtpServer(
          ociSmtpHost,
          port: ociSmtpPort,
          ssl: false,
          allowInsecure: true,
          username: ociSmtpUser.trim(),
          password: ociSmtpPass.trim(),
        );

        final ociMessage = Message()
          ..from = Address(ociSenderEmail, 'Groovy')
          ..recipients.add(cleanRecipient)
          ..subject = 'Tu código de seguridad de Groovy: $code'
          ..html = htmlContent;

        await send(ociMessage, ociServer).timeout(const Duration(seconds: 15));
        debugPrint('[EmailVerification] ¡Correo enviado con éxito vía Oracle Cloud!');
        return true;
      } catch (ociError) {
        debugPrint('[EmailVerification] Falló el envío con Oracle Cloud: $ociError. Intentando con respaldo Gmail...');
      }
    }

    // 2. Respaldo: Enviar vía Gmail SMTP
    try {
      debugPrint('[EmailVerification] Enviando correo vía Gmail SMTP ($gmailUser)...');
      final gmailServer = gmail(gmailUser, gmailPass.replaceAll(' ', ''));

      final gmailMessage = Message()
        ..from = Address(gmailUser, 'Groovy')
        ..recipients.add(cleanRecipient)
        ..subject = 'Tu código de seguridad de Groovy: $code'
        ..html = htmlContent;

      await send(gmailMessage, gmailServer).timeout(const Duration(seconds: 15));
      debugPrint('[EmailVerification] ¡Correo enviado con éxito vía Gmail!');
      return true;
    } catch (gmailError) {
      debugPrint('[EmailVerification] Error enviando con Gmail SMTP: $gmailError');
      return false;
    }
  }

  /// Construye la plantilla visual HTML del correo electrónico
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

    return '''<!DOCTYPE html>
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
</html>''';
  }
}
