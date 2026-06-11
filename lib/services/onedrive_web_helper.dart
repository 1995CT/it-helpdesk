// Web implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Use localStorage so verifier survives OAuth redirect
void saveVerifier(String verifier) =>
    html.window.localStorage['od_cv'] = verifier;

String getVerifier() => html.window.localStorage['od_cv'] ?? '';

void clearVerifier() => html.window.localStorage.remove('od_cv');

void redirect(String url) => html.window.location.href = url;

// Clear URL params without page reload
void clearUrlParams() {
  final uri = Uri.parse(html.window.location.href);
  html.window.history.replaceState(null, '', uri.origin + uri.path);
}

String getCurrentUrl() => html.window.location.href;

// Temporarily store tokens in localStorage until user authenticates
void savePendingTokens(String accessToken, String refreshToken, int expiresIn) {
  html.window.localStorage['od_pending_access'] = accessToken;
  html.window.localStorage['od_pending_refresh'] = refreshToken;
  html.window.localStorage['od_pending_expiry'] = expiresIn.toString();
}

Map<String, String>? getPendingTokens() {
  final access = html.window.localStorage['od_pending_access'];
  final refresh = html.window.localStorage['od_pending_refresh'];
  final expiry = html.window.localStorage['od_pending_expiry'];
  if (access == null || refresh == null || expiry == null) return null;
  return {'access': access, 'refresh': refresh, 'expiry': expiry};
}

void clearPendingTokens() {
  html.window.localStorage.remove('od_pending_access');
  html.window.localStorage.remove('od_pending_refresh');
  html.window.localStorage.remove('od_pending_expiry');
}
