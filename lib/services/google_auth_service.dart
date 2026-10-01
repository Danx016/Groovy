import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

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

  static String _d(List<int> bytes) => String.fromCharCodes(bytes.map((b) => b ^ 0x5A));

  // Desktop (Windows/macOS/Linux) OAuth Client Credentials
  static String get webClientId => _d(const [
        105, 107, 98, 99, 110, 98, 104, 108, 99, 99, 109, 104, 119, 51, 42, 44,
        63, 61, 42, 40, 111, 106, 62, 52, 59, 59, 111, 110, 49, 55, 60, 108,
        54, 61, 106, 109, 56, 55, 63, 55, 48, 98, 46, 48, 99, 116, 59, 42,
        42, 41, 116, 61, 53, 53, 61, 54, 63, 47, 41, 63, 40, 57, 53, 52,
        46, 63, 52, 46, 116, 57, 53, 55
      ]);

  static String get webClientSecret => _d(const [
        29, 21, 25, 9, 10, 2, 119, 107, 0, 109, 43, 63, 47, 63, 60, 108, 52,
        19, 19, 62, 54, 19, 43, 3, 15, 13, 8, 17, 25, 53, 106, 119, 30, 110,
        43
      ]);

  // Android OAuth Client Credentials (project: groovy-510319)
  static String get androidClientId => _d(const [
        99, 99, 106, 107, 105, 99, 99, 110, 104, 106, 104, 107, 119, 109, 111,
        52, 48, 111, 55, 99, 63, 46, 105, 49, 63, 110, 106, 43, 47, 110,
        56, 98, 40, 60, 111, 42, 41, 111, 57, 49, 57, 54, 48, 111, 57,
        116, 59, 42, 42, 41, 116, 61, 53, 53, 61, 54, 63, 47, 41, 63,
        40, 57, 53, 52, 46, 63, 52, 46, 116, 57, 53, 55
      ]);

  static const int loopbackPort = 42426;
  static const String loopbackRedirectUri = 'http://127.0.0.1:$loopbackPort';

  /// Builds a GoogleSignIn instance.
  /// On Android, serverClientId must be null — Play Services uses the registered SHA-1
  /// fingerprint to identify the app. Passing a web client ID causes ApiException 10.
  /// serverClientId is only used on Desktop (Windows/Linux/macOS) for the loopback OAuth flow.
  GoogleSignIn _buildGoogleSignIn({bool withServerClientId = false}) {
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    return GoogleSignIn(
      clientId: null,
      // On Android: always null. On Desktop: use webClientId for server token exchange.
      serverClientId: (withServerClientId && !isAndroid) ? webClientId : null,
      scopes: const ['email', 'profile'],
    );
  }

  /// Signs in the user with Google.
  /// Uses native Google Play Services on Android, and OAuth 2.0 Loopback on Windows/macOS/Linux.
  Future<GoogleUserInfo?> signIn() async {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      return _signInOAuthWeb();
    } else {
      return _signInMobile();
    }
  }

  bool _isSigningIn = false;

  bool _isUserCancellation(String? code, String? message) {
    final text = '${code ?? ''} ${message ?? ''}'.toLowerCase();
    return text.contains('sign_in_canceled') ||
        text.contains('12501') ||
        text.contains('canceled') ||
        text.contains('cancelled') ||
        text.contains('user_canceled');
  }



  /// Mobile Google Sign-In using native Google Play Services modal inside the app.
  /// If native Google Play Services fails (e.g., error 12500 due to SHA-1 mismatch or unavailable Play Services),
  /// it automatically falls back to the OAuth browser flow to guarantee successful sign-in.
  Future<GoogleUserInfo?> _signInMobile() async {
    if (_isSigningIn) {
      debugPrint('[GoogleAuth] Sign-in already in progress, ignoring duplicate tap');
      return null;
    }
    _isSigningIn = true;

    try {
      GoogleSignInAccount? account;

      try {
        final gSignIn = _buildGoogleSignIn(withServerClientId: false);
        account = await gSignIn.signIn();
      } on PlatformException catch (pe) {
        debugPrint('[GoogleAuth] Native sign-in PlatformException: ${pe.code} - ${pe.message}');
        if (_isUserCancellation(pe.code, pe.message)) {
          debugPrint('[GoogleAuth] Native sign-in dismissed by user');
          return null;
        }
        // If native Google Play Services throws 12500, 10, or sign_in_failed,
        // seamlessly fall back to universal OAuth browser flow
        debugPrint('[GoogleAuth] Native sign-in failed (${pe.code}), falling back to OAuth Web flow...');
        return await _signInOAuthWeb();
      } catch (e) {
        debugPrint('[GoogleAuth] Native sign-in non-platform exception: $e');
        if (_isUserCancellation(null, e.toString())) {
          return null;
        }
        debugPrint('[GoogleAuth] Native sign-in failed ($e), falling back to OAuth Web flow...');
        return await _signInOAuthWeb();
      }

      if (account == null) {
        debugPrint('[GoogleAuth] Native sign-in returned null (user cancelled)');
        return null;
      }

      String? idToken;
      try {
        final authentication = await account.authentication;
        idToken = authentication.idToken;
      } catch (e) {
        debugPrint('[GoogleAuth] Note obtaining authentication tokens: $e');
      }

      return GoogleUserInfo(
        id: account.id,
        email: account.email,
        name: account.displayName ?? (account.email.isNotEmpty ? account.email.split('@').first : 'Usuario'),
        avatarUrl: account.photoUrl,
        idToken: idToken,
      );
    } finally {
      _isSigningIn = false;
    }
  }

  /// Generates a cryptographic PKCE code verifier and code challenge (S256)
  Map<String, String> _generatePkcePair() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final codeVerifier = base64UrlEncode(values).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
    final digest = sha256.convert(utf8.encode(codeVerifier));
    final codeChallenge = base64UrlEncode(digest.bytes).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
    return {
      'verifier': codeVerifier,
      'challenge': codeChallenge,
    };
  }

  /// Universal OAuth 2.0 flow using local loopback HTTP server and system browser
  Future<GoogleUserInfo?> _signInOAuthWeb() async {
    HttpServer? server4;
    HttpServer? server6;

    try {
      // Bind loopback servers on 127.0.0.1 and [::1] with shared: true to allow instant port reuse
      for (int attempt = 0; attempt < 5; attempt++) {
        if (server4 == null) {
          try {
            server4 = await HttpServer.bind(InternetAddress.loopbackIPv4, loopbackPort, shared: true);
            debugPrint('[GoogleAuth] Bound IPv4 loopback (127.0.0.1:$loopbackPort)');
          } catch (e) {
            debugPrint('[GoogleAuth] IPv4 bind attempt ${attempt + 1} note: $e');
          }
        }
        if (server6 == null) {
          try {
            server6 = await HttpServer.bind(InternetAddress.loopbackIPv6, loopbackPort, shared: true);
            debugPrint('[GoogleAuth] Bound IPv6 loopback ([::1]:$loopbackPort)');
          } catch (e) {
            debugPrint('[GoogleAuth] IPv6 bind attempt ${attempt + 1} note: $e');
          }
        }

        if (server4 != null || server6 != null) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (server4 == null && server6 == null) {
        throw Exception('No se pudo iniciar el servidor local en el puerto $loopbackPort.');
      }

      final completer = Completer<String?>();
      final pkce = _generatePkcePair();

      void handleRequest(HttpRequest req) async {
        try {
          final uri = req.uri;
          debugPrint('[GoogleAuth] ▶ ${req.method} ${uri.path}?${uri.query.length > 80 ? uri.query.substring(0, 80) + "..." : uri.query}');

          req.response.headers.add('Access-Control-Allow-Origin', '*');
          req.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          req.response.headers.add('Access-Control-Allow-Headers', '*');
          req.response.headers.add('Access-Control-Allow-Private-Network', 'true');

          if (req.method == 'OPTIONS') {
            req.response.statusCode = HttpStatus.noContent;
            await req.response.close();
            return;
          }

          if (uri.path == '/favicon.ico') {
            req.response.statusCode = HttpStatus.notFound;
            await req.response.close();
            return;
          }

          final code = uri.queryParameters['code'];
          final error = uri.queryParameters['error'];
          final codePreview = code != null
              ? code.substring(0, code.length > 20 ? 20 : code.length) + '...'
              : 'null';
          debugPrint('[GoogleAuth] code=$codePreview  error=$error');

          if (code == null && error == null) {
            debugPrint('[GoogleAuth] Preflight/probe received — returning 200');
            req.response.statusCode = HttpStatus.ok;
            req.response.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
            req.response.write('OK');
            await req.response.close();
            return;
          }

          final isSuccess = error == null && code != null;
          final pageTitle = isSuccess ? 'Autenticación exitosa' : 'Error de autenticación';

          final htmlContent = '''<!DOCTYPE html>
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
    .container { width: 100%; max-width: 440px; display: flex; flex-direction: column; align-items: center; }
    .brand-header { display: flex; align-items: center; gap: 10px; margin-bottom: 24px; }
    .brand-logo { width: 32px; height: 32px; border-radius: 8px; }
    .brand-name { font-size: 20px; font-weight: 800; letter-spacing: -0.5px; color: #ffffff; }
    .brand-badge { font-size: 11px; font-weight: 600; color: #9494a0; background: rgba(255,255,255,0.06); padding: 2px 8px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.08); }
    .card { width: 100%; background: #14141b; border: 1px solid rgba(255,255,255,0.08); border-radius: 20px; padding: 36px 32px; text-align: center; box-shadow: 0 20px 40px rgba(0,0,0,0.45); }
    .status-icon { width: 60px; height: 60px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; background: ${isSuccess ? 'rgba(250,36,60,0.12)' : 'rgba(255,69,58,0.12)'}; border: 1px solid ${isSuccess ? 'rgba(250,36,60,0.3)' : 'rgba(255,69,58,0.3)'}; }
    .status-icon svg { width: 28px; height: 28px; stroke: ${isSuccess ? '#FA243C' : '#FF453A'}; stroke-width: 2.5; stroke-linecap: round; stroke-linejoin: round; fill: none; }
    h1 { font-size: 21px; font-weight: 700; letter-spacing: -0.4px; color: #ffffff; margin-bottom: 8px; }
    .description { font-size: 14px; line-height: 1.55; color: #9d9da8; margin-bottom: 24px; }
    .description strong { color: #ffffff; font-weight: 600; }
    .hint-box { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06); border-radius: 12px; padding: 12px 14px; display: flex; align-items: center; gap: 10px; text-align: left; margin-bottom: 24px; }
    .hint-box svg { width: 18px; height: 18px; stroke: #FA243C; stroke-width: 2; flex-shrink: 0; fill: none; }
    .hint-box span { font-size: 12.5px; color: #b5b5c2; line-height: 1.4; }
    .btn-primary { display: inline-flex; align-items: center; justify-content: center; gap: 8px; width: 100%; background: #FA243C; color: #ffffff; text-decoration: none; font-size: 14px; font-weight: 700; padding: 12px 20px; border-radius: 12px; border: none; cursor: pointer; }
    .footer-note { margin-top: 24px; font-size: 12px; color: #555562; display: flex; align-items: center; gap: 6px; }
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
      <span class="brand-badge">Acceso Seguro</span>
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
      <div class="hint-box">
        <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>
        <span>${isSuccess
            ? 'Ya puedes volver a la aplicación Groovy en tu equipo.'
            : 'Detalle: <code>${error ?? 'Cancelado por el usuario'}</code>'}</span>
      </div>
      <button class="btn-primary" onclick="window.close();">Cerrar esta pestaña</button>
    </div>
    <div class="footer-note">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
      <span>Conexión segura OAuth 2.0</span>
    </div>
  </div>
  <script>setTimeout(function() { window.close(); }, 3000);</script>
</body>
</html>
''';

          final bodyBytes = utf8.encode(htmlContent);
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
          req.response.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length);
          req.response.headers.set(HttpHeaders.connectionHeader, 'close');
          req.response.add(bodyBytes);
          await req.response.flush();
          await req.response.close();
          debugPrint('[GoogleAuth] HTML response sent and connection closed');

          if (!completer.isCompleted) {
            if (error != null) {
              if (error == 'access_denied') {
                completer.complete(null);
              } else {
                completer.completeError(Exception('Google auth error: $error'));
              }
            } else if (code != null) {
              debugPrint('[GoogleAuth] ✅ Code received — completing completer');
              completer.complete(code);
            }
          }
        } catch (err) {
          debugPrint('[GoogleAuth] HTTP request handling error: $err');
        }
      }

      server4?.listen(handleRequest);
      server6?.listen(handleRequest);

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': webClientId,
        'redirect_uri': loopbackRedirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': pkce['challenge']!,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      bool launched = false;
      try {
        launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }

      if (!launched) {
        try {
          launched = await launchUrl(authUrl, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched) {
        throw Exception('No se pudo abrir el navegador web para iniciar sesión.');
      }

      debugPrint('[GoogleAuth] Browser launched — waiting for callback on $loopbackRedirectUri...');

      // Timeout after 5 minutes
      final code = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('Tiempo de espera agotado. No se completó el inicio de sesión en el navegador.'),
      );

      if (code == null) return null;

      debugPrint('[GoogleAuth] Exchanging code for tokens...');

      // Exchange authorization code for tokens (with PKCE code_verifier)
      final tokenRes = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': webClientId,
          'client_secret': webClientSecret,
          'redirect_uri': loopbackRedirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': pkce['verifier']!,
        },
      ).timeout(const Duration(seconds: 15));

      if (tokenRes.statusCode != 200) {
        debugPrint('[GoogleAuth] Token exchange failed: ${tokenRes.body}');
        throw Exception('Error al canjear código de Google (${tokenRes.statusCode}): ${tokenRes.body}');
      }

      debugPrint('[GoogleAuth] Token exchange successful');

      final tokenData = jsonDecode(utf8.decode(tokenRes.bodyBytes)) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String?;
      final idToken = tokenData['id_token'] as String?;

      if (accessToken == null) throw Exception('No se recibió token de acceso de Google');

      // Fetch user profile
      final userRes = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 15));

      if (userRes.statusCode != 200) {
        throw Exception('Error al obtener perfil de Google (${userRes.statusCode})');
      }

      final userData = jsonDecode(utf8.decode(userRes.bodyBytes)) as Map<String, dynamic>;
      final email = userData['email'] as String? ?? '';
      final name = userData['name'] as String? ?? email.split('@').first;
      final picture = userData['picture'] as String?;
      final subId = userData['sub'] as String? ?? email;

      debugPrint('[GoogleAuth] ✅ Login successful for $email');

      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }

      return GoogleUserInfo(
        id: subId,
        email: email,
        name: name,
        avatarUrl: picture,
        idToken: idToken,
      );
    } catch (e) {
      debugPrint('[GoogleAuth] Desktop flow error: $e');
      rethrow;
    } finally {
      await server4?.close(force: true).catchError((_) {});
      await server6?.close(force: true).catchError((_) {});
      debugPrint('[GoogleAuth] Servers closed');
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _buildGoogleSignIn().signOut();
      }
    } catch (_) {}
  }
}

