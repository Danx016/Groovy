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

  /// Construye la plantilla visual HTML del correo electrónico con el diseño oficial de Groovy
  static String _buildHtmlEmail({
    required String recipientEmail,
    required String code,
  }) {
    final digits = code.split('');
    final digitsHtml = digits.map((d) => '''
      <td style="padding: 0 4px;" align="center">
        <div style="width: 46px; height: 58px; line-height: 58px; background: rgba(250, 36, 60, 0.1); border: 1.5px solid rgba(250, 36, 60, 0.45); border-radius: 14px; font-size: 30px; font-weight: 800; color: #FA243C; text-align: center; font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; box-shadow: 0 4px 12px rgba(250, 36, 60, 0.15);">
          $d
        </div>
      </td>
    ''').join('');

    return '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Código de Seguridad · Groovy</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">
  <!--[if mso]>
  <style type="text/css">
    body, table, td {font-family: Arial, Helvetica, sans-serif !important;}
  </style>
  <![endif]-->
</head>
<body style="margin: 0; padding: 0; background-color: #07080a; font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased; color: #f1f1f4;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #07080a; min-height: 100vh; padding: 40px 16px;">
    <tr>
      <td align="center" valign="middle">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 480px; background: #111217; border-radius: 24px; border: 1px solid rgba(255, 255, 255, 0.08); box-shadow: 0 24px 48px rgba(0, 0, 0, 0.6); overflow: hidden; text-align: center;">
          
          <!-- Top Accent Line -->
          <tr>
            <td height="4" style="background: linear-gradient(90deg, #FA243C 0%, #FF5E62 50%, #FA243C 100%);"></td>
          </tr>

          <!-- Brand Header -->
          <tr>
            <td style="padding: 36px 32px 20px 32px;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center">
                <tr>
                  <td align="center">
                    <!-- Brand Icon -->
                    <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                      <tr>
                        <td align="center" style="width: 56px; height: 56px; background: linear-gradient(135deg, #FA243C 0%, #D81329 100%); border-radius: 16px; box-shadow: 0 8px 24px rgba(250, 36, 60, 0.4);">
                          <span style="font-size: 26px; line-height: 56px; color: #ffffff;">🎵</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <h1 style="margin: 16px 0 0 0; font-size: 24px; font-weight: 800; letter-spacing: -0.6px; color: #ffffff;">Groovy</h1>
              
              <div style="display: inline-block; margin-top: 8px; padding: 4px 12px; background: rgba(250, 36, 60, 0.12); border: 1px solid rgba(250, 36, 60, 0.25); border-radius: 20px;">
                <span style="font-size: 11px; font-weight: 700; color: #FA243C; letter-spacing: 0.5px; text-transform: uppercase;">Seguridad de Cuenta</span>
              </div>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 0 32px 20px 32px;">
              <h2 style="margin: 0 0 10px 0; font-size: 19px; font-weight: 700; letter-spacing: -0.4px; color: #ffffff;">
                Restablecer tu contraseña
              </h2>
              <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #9d9da8;">
                Recibimos una solicitud para cambiar la contraseña de tu cuenta de Groovy vinculada a <strong style="color: #ffffff;">$recipientEmail</strong>.
              </p>
              <p style="margin: 10px 0 0 0; font-size: 13.5px; line-height: 1.5; color: #787885;">
                Ingresa el siguiente código de verificación en la aplicación:
              </p>
            </td>
          </tr>

          <!-- OTP Digits Box -->
          <tr>
            <td style="padding: 10px 20px 24px 20px;" align="center">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center">
                <tr>
                  $digitsHtml
                </tr>
              </table>
            </td>
          </tr>

          <!-- Security & Expiration Info -->
          <tr>
            <td style="padding: 0 32px 30px 32px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 14px; padding: 14px 16px; text-align: left;">
                <tr>
                  <td width="28" valign="top" style="padding-top: 1px;">
                    <div style="width: 22px; height: 22px; background: rgba(250, 36, 60, 0.15); border-radius: 50%; text-align: center; line-height: 22px; font-size: 12px; color: #FA243C;">
                      ⏱
                    </div>
                  </td>
                  <td style="padding-left: 10px;">
                    <div style="font-size: 12.5px; color: #e4e4e7; font-weight: 700; margin-bottom: 2px;">
                      Válido durante 15 minutos
                    </div>
                    <div style="font-size: 11.5px; color: #82828e; line-height: 1.45;">
                      Si tú no solicitaste este cambio, puedes ignorar este correo; tu cuenta seguirá protegida.
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 22px 32px; border-top: 1px solid rgba(255, 255, 255, 0.06); background-color: #0b0c10;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td align="center">
                    <div style="font-size: 12px; font-weight: 700; color: #8e8e9a; letter-spacing: -0.2px;">
                      Groovy Music
                    </div>
                    <div style="font-size: 11px; color: #555562; margin-top: 4px;">
                      Streaming de música de alta fidelidad sin límites
                    </div>
                    <div style="font-size: 10.5px; color: #40404c; margin-top: 8px;">
                      © ${DateTime.now().year} Groovy App. Todos los derechos reservados.
                    </div>
                  </td>
                </tr>
              </table>
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
