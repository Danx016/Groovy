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

        req.response.headers.contentType = ContentType.html;
        req.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Groovy - Autenticación</title>
  <style>
    body { background: #121214; color: #fff; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #1A1A1E; padding: 40px; border-radius: 20px; border: 1px solid rgba(255,255,255,0.1); text-align: center; max-width: 420px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
    h1 { color: #1ED760; margin: 0 0 12px; font-size: 22px; }
    p { color: #A0A0A0; font-size: 14px; line-height: 1.5; margin: 0 0 16px; }
    .btn { display: inline-block; background: #1ED760; color: #000; font-weight: bold; text-decoration: none; padding: 10px 24px; border-radius: 20px; font-size: 13px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>¡Autenticación Exitosa!</h1>
    <p>Has iniciado sesión con Google en <strong>Groovy</strong>.<br>Ya puedes cerrar esta ventana y regresar a la aplicación.</p>
    <a href="javascript:window.close();" class="btn">Cerrar pestaña</a>
  </div>
  <script>setTimeout(function() { window.close(); }, 3000);</script>
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
