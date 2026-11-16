import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 토큰 저장·조회·삭제 규칙을 한곳에 모은 추상화.
/// 로그인·로그아웃·Interceptor가 FlutterSecureStorage에 직접 의존하지 않게 함
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// 실제 구현. iOS Keychain / Android Keystore 기반으로 암호화해 저장.
/// 장르 같은 비민감 값은 shared_preferences, 토큰은 여기 (비밀번호는 어디에도 저장하지 않음)
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);
  static const _accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}
