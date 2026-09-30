import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleUserInfo {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? idToken;

  GoogleUserInfo({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.idToken,
  });
}

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  // Web & Windows OAuth Client Credentials (assembled dynamically)
  static String get webClientId => String.fromCharCodes([
    51, 49, 56, 57, 52, 56, 50, 54, 57, 57, 55, 50, 45, 116, 114, 56, 54, 54, 99, 105, 50, 113, 104, 112, 49, 112, 57, 116, 114, 50, 104, 56, 106, 107, 98, 101, 55, 103, 50, 98, 114, 49, 55, 49, 100, 46, 97, 112, 112, 115, 46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109
  ]);

  static String get webClientSecret => String.fromCharCodes([
    71, 79, 67, 83, 80, 88, 45, 86, 109, 110, 122, 113, 101, 107, 88, 49, 84, 69, 85, 115, 115, 73, 74, 65, 83, 75, 81, 119, 79, 57, 45, 103, 54, 97, 68
  ]);

  // Android OAuth Client Credentials
  static String get androidClientId => String.fromCharCodes([
    51, 49, 56, 57, 52, 56, 50, 54, 57, 57, 55, 50, 45, 97, 118, 98, 55, 102, 49, 98, 101, 50, 51, 107, 112, 102, 111, 117, 117, 104, 114, 55, 112, 54, 98, 111, 97, 53, 48, 117, 51, 105, 110, 110, 56, 46, 97, 112, 112, 115, 46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109
  ]);

  static const int loopbackPort = 42426;
  static const String loopbackRedirectUri = 'http://localhost:$loopbackPort/oauth/callback';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
    scopes: ['email', 'profile', 'openid'],
  );

  /// Signs in the user with Google.
  /// Uses native Google Play Services on Android, and OAuth 2.0 Loopback on Windows/macOS/Linux.
  Future<GoogleUserInfo?> signIn() async {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      return _signInDesktop();
    } else {
      return _signInMobile();
    }
  }

  /// Mobile Google Sign-In using native Google Play Services
  Future<GoogleUserInfo?> _signInMobile() async {
    try {
      // Disconnect previous session to always allow account picker
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleAuth] Mobile login cancelled by user');
        return null;
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;

      return GoogleUserInfo(
        id: account.id,
        email: account.email,
        name: account.displayName ?? account.email.split('@').first,
        avatarUrl: account.photoUrl,
        idToken: idToken,
      );
    } catch (e) {
      debugPrint('[GoogleAuth] Mobile login error: $e');
      rethrow;
    }
  }

  /// Desktop Google Sign-In using local loopback HTTP server and system browser
  Future<GoogleUserInfo?> _signInDesktop() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, loopbackPort);
    } catch (e) {
      debugPrint('[GoogleAuth] Could not bind port $loopbackPort: $e');
      throw Exception('El puerto local de autenticación está ocupado. Intenta de nuevo.');
    }

    final completer = Completer<String?>();

    final sub = server.listen((HttpRequest req) async {
      final uri = req.uri;
      if (uri.path == '/oauth/callback') {
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        final isSuccess = error == null;
        final pageTitle = isSuccess ? 'Autenticación exitosa' : 'Error de autenticación';

        req.response.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
        req.response.encoding = utf8;
        req.response.write('''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Groovy · $pageTitle</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background-color: #0b0b0f;
      color: #f1f1f4;
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
      -webkit-font-smoothing: antialiased;
    }
    .container {
      width: 100%;
      max-width: 440px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .brand-header {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 24px;
    }
    .brand-logo {
      width: 32px;
      height: 32px;
      border-radius: 8px;
    }
    .brand-name {
      font-size: 20px;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: #ffffff;
    }
    .brand-badge {
      font-size: 11px;
      font-weight: 600;
      color: #9494a0;
      background: rgba(255, 255, 255, 0.06);
      padding: 2px 8px;
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .card {
      width: 100%;
      background: #14141b;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 20px;
      padding: 36px 32px;
      text-align: center;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.45);
    }
    .status-icon {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px;
      background: ${isSuccess ? 'rgba(250, 36, 60, 0.12)' : 'rgba(255, 69, 58, 0.12)'};
      border: 1px solid ${isSuccess ? 'rgba(250, 36, 60, 0.3)' : 'rgba(255, 69, 58, 0.3)'};
    }
    .status-icon svg {
      width: 28px;
      height: 28px;
      stroke: ${isSuccess ? '#FA243C' : '#FF453A'};
      stroke-width: 2.5;
      stroke-linecap: round;
      stroke-linejoin: round;
      fill: none;
    }
    h1 {
      font-size: 21px;
      font-weight: 700;
      letter-spacing: -0.4px;
      color: #ffffff;
      margin-bottom: 8px;
    }
    .description {
      font-size: 14px;
      line-height: 1.55;
      color: #9d9da8;
      margin-bottom: 24px;
    }
    .description strong {
      color: #ffffff;
      font-weight: 600;
    }
    .hint-box {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 12px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      gap: 10px;
      text-align: left;
      margin-bottom: 24px;
    }
    .hint-box svg {
      width: 18px;
      height: 18px;
      stroke: #FA243C;
      stroke-width: 2;
      flex-shrink: 0;
      fill: none;
    }
    .hint-box span {
      font-size: 12.5px;
      color: #b5b5c2;
      line-height: 1.4;
    }
    .btn-group {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .btn-primary {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      width: 100%;
      background: #FA243C;
      color: #ffffff;
      text-decoration: none;
      font-size: 14px;
      font-weight: 700;
      padding: 12px 20px;
      border-radius: 12px;
      border: none;
      cursor: pointer;
      transition: background 0.15s ease, transform 0.1s ease;
    }
    .btn-primary:hover {
      background: #e01b31;
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: transparent;
      color: #848492;
      border: none;
      font-size: 13px;
      font-weight: 600;
      padding: 8px;
      cursor: pointer;
      text-decoration: none;
      transition: color 0.15s;
    }
    .btn-secondary:hover {
      color: #ffffff;
    }
    .footer-note {
      margin-top: 24px;
      font-size: 12px;
      color: #555562;
      display: flex;
      align-items: center;
      gap: 6px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="brand-header">
      <svg class="brand-logo" viewBox="0 0 36 36" fill="none">
        <rect width="36" height="36" rx="8" fill="#FA243C"/>
        <path d="M22 10V22.5C22 24.43 20.43 26 18.5 26C16.57 26 15 24.43 15 22.5C15 20.57 16.57 19 18.5 19C19.38 19 20.19 19.33 20.8 19.87V13H25V10H22Z" fill="white"/>
      </svg>
      <span class="brand-name">Groovy</span>
      <span class="brand-badge">Desktop</span>
    </div>

    <div class="card">
      <div class="status-icon">
        ${isSuccess
            ? '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>'
            : '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>'}
      </div>

      <h1>${isSuccess ? '¡Sesión iniciada con éxito!' : 'Error de autenticación'}</h1>
      <p class="description">
        ${isSuccess
            ? 'Tu cuenta de Google se ha vinculado correctamente con <strong>Groovy</strong>.'
            : 'No se pudo completar la autenticación con Google.'}
      </p>

      ${isSuccess ? '''
      <div class="hint-box">
        <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>
        <span>Ya puedes volver a la aplicación Groovy en tu equipo para seguir escuchando tu música.</span>
      </div>
      ''' : '''
      <div class="hint-box">
        <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
        <span>Detalle del error: <code>$error</code></span>
      </div>
      '''}

      <div class="btn-group">
        <button class="btn-primary" onclick="window.close();">Cerrar esta pestaña</button>
      </div>
    </div>

    <div class="footer-note">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
      <span>Conexión segura OAuth 2.0</span>
    </div>
  </div>

  <script>
    setTimeout(function() {
      window.close();
    }, 4000);
  </script>
</body>
</html>
''');
        await req.response.close();

        if (error != null) {
          completer.completeError(Exception('Google auth error: $error'));
        } else if (code != null) {
          completer.complete(code);
        } else {
          completer.complete(null);
        }
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': webClientId,
      'redirect_uri': loopbackRedirectUri,
      'response_type': 'code',
      'scope': 'email profile openid',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    if (!launched) {
      await sub.cancel();
      await server.close(force: true);
      throw Exception('No se pudo abrir el navegador web para iniciar sesiÃ³n.');
    }

    try {
      // Timeout after 2 minutes if user abandons browser
      final code = await completer.future.timeout(const Duration(minutes: 2));
      await sub.cancel();
      await server.close(force: true);

      if (code == null) return null;

      // Exchange authorization code for tokens
      final tokenRes = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': webClientId,
          'client_secret': webClientSecret,
          'redirect_uri': loopbackRedirectUri,
          'grant_type': 'authorization_code',
        },
      ).timeout(const Duration(seconds: 10));

      if (tokenRes.statusCode != 200) {
        debugPrint('[GoogleAuth] Token exchange failed: ${tokenRes.body}');
        throw Exception('Error al canjear cÃ³digo de Google (${tokenRes.statusCode})');
      }

      final tokenData = jsonDecode(utf8.decode(tokenRes.bodyBytes)) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String?;
      final idToken = tokenData['id_token'] as String?;

      if (accessToken == null) throw Exception('No se recibiÃ³ token de acceso');

      // Fetch user profile
      final userRes = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 8));

      if (userRes.statusCode != 200) {
        throw Exception('Error al obtener perfil de Google');
      }

      final userData = jsonDecode(utf8.decode(userRes.bodyBytes)) as Map<String, dynamic>;
      final email = userData['email'] as String? ?? '';
      final name = userData['name'] as String? ?? email.split('@').first;
      final picture = userData['picture'] as String?;
      final subId = userData['sub'] as String? ?? email;

      return GoogleUserInfo(
        id: subId,
        email: email,
        name: name,
        avatarUrl: picture,
        idToken: idToken,
      );
    } catch (e) {
      await sub.cancel();
      await server.close(force: true);
      debugPrint('[GoogleAuth] Desktop flow error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
  }
}

