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
        final title = isSuccess ? '¡Autenticación Exitosa!' : 'Error de Autenticación';
        final message = isSuccess
            ? 'Has iniciado sesión con Google en <strong style="color: #FA243C;">Groovy</strong>.<br>Ya puedes cerrar esta ventana y regresar a la aplicación.'
            : 'No se pudo completar el inicio de sesión.<br>Código de error: <code>$error</code>';

        req.response.headers.contentType = ContentType.html;
        req.response.write('''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Groovy · $title</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background-color: #0C0D12;
      background-image: radial-gradient(circle at 50% 40%, rgba(250, 36, 60, 0.15) 0%, rgba(12, 13, 18, 0) 70%);
      color: #FFFFFF;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 20px;
      overflow: hidden;
    }
    .card {
      background: rgba(22, 22, 28, 0.85);
      backdrop-filter: blur(28px) saturate(180%);
      -webkit-backdrop-filter: blur(28px) saturate(180%);
      padding: 44px 36px;
      border-radius: 24px;
      border: 1px solid rgba(255, 255, 255, 0.12);
      text-align: center;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 30px 60px -12px rgba(0, 0, 0, 0.7), 0 0 40px rgba(250, 36, 60, 0.12);
      animation: fadeIn 0.4s ease-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(16px) scale(0.98); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    .icon-wrapper {
      width: 72px;
      height: 72px;
      margin: 0 auto 20px;
      background: linear-gradient(135deg, #1E1E26 0%, #16161E 100%);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      position: relative;
      box-shadow: 0 12px 28px rgba(0,0,0,0.4);
    }
    .status-badge {
      position: absolute;
      bottom: -4px;
      right: -4px;
      width: 26px;
      height: 26px;
      border-radius: 50%;
      background: ${isSuccess ? 'linear-gradient(135deg, #FA243C, #FF4B63)' : '#E02424'};
      border: 2.5px solid #0C0D12;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 0 14px rgba(250, 36, 60, 0.6);
    }
    .status-badge svg {
      width: 14px;
      height: 14px;
      fill: #fff;
    }
    h1 {
      color: #FFFFFF;
      margin: 0 0 10px;
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -0.4px;
    }
    p {
      color: rgba(255, 255, 255, 0.72);
      font-size: 14px;
      line-height: 1.6;
      margin: 0 0 24px;
    }
    code {
      background: rgba(255,255,255,0.08);
      padding: 2px 6px;
      border-radius: 6px;
      font-size: 13px;
      color: #FF5C65;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #FA243C 0%, #D81B32 100%);
      color: #FFFFFF;
      font-weight: 600;
      text-decoration: none;
      padding: 12px 32px;
      border-radius: 30px;
      font-size: 14px;
      letter-spacing: -0.2px;
      transition: all 0.2s ease;
      box-shadow: 0 8px 24px rgba(250, 36, 60, 0.4);
      cursor: pointer;
      border: none;
      outline: none;
    }
    .btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 12px 28px rgba(250, 36, 60, 0.55);
      filter: brightness(1.08);
    }
    .btn:active {
      transform: translateY(0);
    }
    .footer {
      margin-top: 18px;
      font-size: 12px;
      color: rgba(255, 255, 255, 0.35);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-wrapper">
      <svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="#FA243C" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M9 18V5l12-2v13"></path>
        <circle cx="6" cy="18" r="3" fill="#FA243C"></circle>
        <circle cx="18" cy="16" r="3" fill="#FA243C"></circle>
      </svg>
      <div class="status-badge">
        ${isSuccess
            ? '<svg viewBox="0 0 24 24"><path d="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z"/></svg>'
            : '<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z"/></svg>'}
      </div>
    </div>
    <h1>$title</h1>
    <p>$message</p>
    <a href="javascript:window.close();" class="btn">Cerrar pestaña</a>
    <div class="footer" id="countdown">Cerrando automáticamente en <span id="sec">3</span>s...</div>
  </div>
  <script>
    var remaining = 3;
    var el = document.getElementById('sec');
    var timer = setInterval(function() {
      remaining--;
      if (el) el.innerText = remaining;
      if (remaining <= 0) {
        clearInterval(timer);
        window.close();
      }
    }, 1000);
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
      throw Exception('No se pudo abrir el navegador web para iniciar sesión.');
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
        throw Exception('Error al canjear código de Google (${tokenRes.statusCode})');
      }

      final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String?;
      final idToken = tokenData['id_token'] as String?;

      if (accessToken == null) throw Exception('No se recibió token de acceso');

      // Fetch user profile
      final userRes = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 8));

      if (userRes.statusCode != 200) {
        throw Exception('Error al obtener perfil de Google');
      }

      final userData = jsonDecode(userRes.body) as Map<String, dynamic>;
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
