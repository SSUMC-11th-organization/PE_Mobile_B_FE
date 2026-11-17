import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// MovieLog JWT 저장소 — 토큰 write/read/delete는 반드시 이 인터페이스로만 접근
// 토큰 값은 절대 print/debugPrint/log로 출력하지 않음 (예외 메시지에도 넣지 않음)
abstract interface class TokenStorage {
  Future<void> writeAccessToken(String token);

  // 저장된 토큰이 없으면 null
  Future<String?> readAccessToken();

  Future<void> deleteAccessToken();
}

// flutter_secure_storage 구현 — iOS Keychain / Android Keystore 기반 암호화 저장
// TMDB 토큰은 여기 저장하지 않음 (.env → TmdbConfig 전용)
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'movielog_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<String?> readAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  @override
  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);
}
