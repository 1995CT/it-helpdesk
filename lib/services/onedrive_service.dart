import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Web-only imports via conditional
// ignore: uri_does_not_exist
import 'onedrive_web_helper.dart'
    if (dart.library.io) 'onedrive_stub_helper.dart' as webHelper;

class OneDriveService {
  static const _clientId = String.fromEnvironment('AZURE_CLIENT_ID');
  static const _tenantId = String.fromEnvironment('AZURE_TENANT_ID');
  static const _redirectUri = 'https://itdesk-pro.vercel.app';
  static const _scope = 'Files.ReadWrite.All offline_access User.Read';

  // ─── PKCE ───────────────────────────────────────────────
  static String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = Random.secure();
    return List.generate(64, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // ─── AUTH FLOW ───────────────────────────────────────────
  static void startAuthFlow() {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    webHelper.saveVerifier(verifier);

    final params = {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': _scope,
      'response_mode': 'query',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'prompt': 'select_account',
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url =
        'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/authorize?$query';

    webHelper.redirect(url);
  }

  static Future<bool> handleCallback(String code) async {
    final verifier = webHelper.getVerifier();
    if (verifier.isEmpty) return false;

    final response = await http.post(
      Uri.parse(
          'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token'),
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Store in localStorage temporarily — no Supabase user session yet
      webHelper.savePendingTokens(
          data['access_token'], data['refresh_token'], data['expires_in']);
      webHelper.clearVerifier();
      return true;
    }
    return false;
  }

  /// Call AFTER user authenticates to flush pending tokens to Supabase
  static Future<void> flushPendingTokens() async {
    final pending = webHelper.getPendingTokens();
    if (pending == null) return;
    await _storeTokens(
        pending['access']!, pending['refresh']!, int.parse(pending['expiry']!));
    webHelper.clearPendingTokens();
  }

  // ─── TOKEN MANAGEMENT ────────────────────────────────────
  static Future<void> _storeTokens(
      String access, String refresh, int expiresIn) async {
    final expiry = DateTime.now()
        .toUtc()
        .add(Duration(seconds: expiresIn))
        .toIso8601String();
    final db = Supabase.instance.client;
    await db
        .from('app_settings')
        .upsert({'key': 'od_access_token', 'value': access, 'updated_at': DateTime.now().toUtc().toIso8601String()});
    await db
        .from('app_settings')
        .upsert({'key': 'od_refresh_token', 'value': refresh, 'updated_at': DateTime.now().toUtc().toIso8601String()});
    await db
        .from('app_settings')
        .upsert({'key': 'od_token_expiry', 'value': expiry, 'updated_at': DateTime.now().toUtc().toIso8601String()});
  }

  static Future<String?> getAccessToken() async {
    try {
      final db = Supabase.instance.client;
      final expiryRow = await db
          .from('app_settings')
          .select('value')
          .eq('key', 'od_token_expiry')
          .maybeSingle();
      if (expiryRow == null) return null;

      final expiry = DateTime.parse(expiryRow['value']);
      if (DateTime.now().toUtc().isBefore(expiry.subtract(const Duration(minutes: 5)))) {
        final row = await db
            .from('app_settings')
            .select('value')
            .eq('key', 'od_access_token')
            .maybeSingle();
        return row?['value'];
      }
      return await _refreshToken();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _refreshToken() async {
    try {
      final db = Supabase.instance.client;
      final row = await db
          .from('app_settings')
          .select('value')
          .eq('key', 'od_refresh_token')
          .maybeSingle();
      if (row == null) return null;

      final response = await http.post(
        Uri.parse(
            'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token'),
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': row['value'],
          'client_id': _clientId,
          'scope': _scope,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storeTokens(data['access_token'],
            data['refresh_token'] ?? row['value'], data['expires_in']);
        return data['access_token'];
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> isConnected() async {
    try {
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', 'od_refresh_token')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disconnect() async {
    final db = Supabase.instance.client;
    await db.from('app_settings').delete().inFilter('key',
        ['od_access_token', 'od_refresh_token', 'od_token_expiry']);
  }

  // ─── FILE UPLOAD ─────────────────────────────────────────
  /// Upload bytes to OneDrive → returns sharing URL or null
  static Future<String?> uploadFile(
      String folder, String filename, Uint8List bytes) async {
    final token = await getAccessToken();
    if (token == null) return null;

    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'bin';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'IT-Helpdesk/$folder/$ts.$ext';

    // Upload via Graph API simple upload (< 4 MB)
    final uploadRes = await http.put(
      Uri.parse(
          'https://graph.microsoft.com/v1.0/me/drive/root:/$path:/content'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
      final data = jsonDecode(uploadRes.body);
      final itemId = data['id'];

      // Create anonymous view link
      final shareRes = await http.post(
        Uri.parse(
            'https://graph.microsoft.com/v1.0/me/drive/items/$itemId/createLink'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'type': 'view', 'scope': 'anonymous'}),
      );

      if (shareRes.statusCode == 200 || shareRes.statusCode == 201) {
        final shareData = jsonDecode(shareRes.body);
        // Convert sharing URL to direct download URL
        final webUrl = shareData['link']?['webUrl'] as String?;
        if (webUrl != null) {
          // OneDrive sharing link → direct download
          return webUrl;
        }
      }
      // Fallback: use webUrl from upload
      return data['webUrl'];
    }
    return null;
  }

  /// Check if URL is from OneDrive
  static bool isOneDriveUrl(String? url) {
    if (url == null) return false;
    return url.contains('onedrive') || url.contains('sharepoint') || url.contains('1drv');
  }
}
