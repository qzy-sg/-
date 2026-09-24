import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/me/avatar.dart';
import 'api_client.dart';

class AuthController extends ChangeNotifier {
  AuthController() {
    ApiClient.onUnauthorized = logout;
    _restore();
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? token;
  String? displayName;
  String? authProvider;
  String? city;
  String? bio;
  String? phoneMasked;
  String? avatarId;
  Uint8List? avatarBytes;
  bool notifyEnabled = true;
  bool ready = false;
  bool busy = false;
  String? error;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  ApiClient get _api => ApiClient(token: token);

  Future<void> _restore() async {
    try {
      token = await _storage.read(key: 'access_token');
      displayName = await _storage.read(key: 'display_name');
      authProvider = await _storage.read(key: 'auth_provider');
      city = await _storage.read(key: 'profile_city');
      bio = await _storage.read(key: 'profile_bio');
      phoneMasked = await _storage.read(key: 'phone_masked');
      avatarId = await _storage.read(key: 'avatar_id') ?? 'orb';
      final prefs = await SharedPreferences.getInstance();
      notifyEnabled = prefs.getBool('notify_enabled') ?? true;
      avatarBytes = decodeAvatarBytes(prefs.getString('avatar_custom_b64'));
    } catch (_) {
      token = null;
      displayName = null;
      authProvider = null;
      city = null;
      bio = null;
      phoneMasked = null;
      avatarId = 'orb';
      avatarBytes = null;
    }
    ready = true;
    notifyListeners();
    if (isLoggedIn) {
      await refreshProfile();
    }
  }

  Future<bool> login(String email, String password) async {
    return _accept(() => ApiClient().login(email.trim(), password));
  }

  Future<bool> loginPhone(String phone, String code) async {
    return _accept(() => ApiClient().loginPhone(phone.trim(), code.trim()));
  }

  Future<bool> loginWechat() async {
    return _accept(() async {
      final challenge = await ApiClient().wechatChallenge();
      final state = '${challenge['state'] ?? ''}'.trim();
      if (state.isEmpty) throw ApiException('授权发起失败，请重试');
      final subject = await _wechatSubject();
      final data = await ApiClient().loginWechat(state: state, subject: subject);
      final user = data['user'];
      if (user is Map) {
        displayName = '${user['display_name'] ?? ''}'.trim();
        authProvider = '${user['provider'] ?? 'wechat'}';
        await _safeWrite('display_name', displayName ?? '');
        await _safeWrite('auth_provider', authProvider ?? '');
      }
      final accessToken = data['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        throw ApiException('登录失败');
      }
      return accessToken;
    });
  }

  Future<String> _wechatSubject() async {
    try {
      final saved = await _storage.read(key: 'wechat_subject');
      if (saved != null && saved.startsWith('wxsub_') && saved.length >= 14) return saved;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('wechat_subject');
      if (saved != null && saved.startsWith('wxsub_') && saved.length >= 14) return saved;
    } catch (_) {}

    final subject = 'wxsub_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    try {
      await _storage.write(key: 'wechat_subject', value: subject);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wechat_subject', subject);
    }
    return subject;
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<bool> register(String phone, String code, String password) async {
    return _accept(() => ApiClient().register(phone: phone.trim(), code: code.trim(), password: password));
  }

  Future<bool> _accept(Future<String> Function() request) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final accessToken = await request();
      token = accessToken;
      await _safeWrite('access_token', accessToken);
      busy = false;
      notifyListeners();
      await refreshProfile();
      return true;
    } on ApiException catch (err) {
      error = err.message;
      busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      error = '登录失败，请重试';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (!isLoggedIn) return;
    try {
      final data = await _api.getAccount();
      await _applyProfile(data);
    } catch (_) {}
  }

  Future<void> _applyProfile(Map<String, dynamic> data) async {
    displayName = '${data['display_name'] ?? ''}'.trim();
    city = '${data['city'] ?? ''}'.trim();
    bio = '${data['bio'] ?? ''}'.trim();
    authProvider = '${data['provider'] ?? authProvider ?? ''}'.trim();
    phoneMasked = data['phone_masked']?.toString();
    avatarId = '${data['avatar_id'] ?? avatarId ?? 'orb'}'.trim();
    if (avatarId!.isEmpty) avatarId = 'orb';
    await _safeWrite('display_name', displayName ?? '');
    await _safeWrite('profile_city', city ?? '');
    await _safeWrite('profile_bio', bio ?? '');
    await _safeWrite('auth_provider', authProvider ?? '');
    await _safeWrite('phone_masked', phoneMasked ?? '');
    await _safeWrite('avatar_id', avatarId ?? 'orb');
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String displayName,
    String city = '',
    String bio = '',
    String avatarId = 'orb',
    Uint8List? avatarBytes,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.updateAccount(
        displayName: displayName.trim(),
        city: city.trim(),
        bio: bio.trim(),
        avatarId: avatarId,
      );
      this.avatarId = avatarId;
      if (avatarId == 'custom' && avatarBytes != null) {
        this.avatarBytes = avatarBytes;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('avatar_custom_b64', encodeAvatarBytes(avatarBytes) ?? '');
      } else if (avatarId != 'custom') {
        this.avatarBytes = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('avatar_custom_b64');
      }
      await _applyProfile(data);
      busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (err) {
      error = err.message;
      busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      error = '保存失败，请重试';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> setNotifyEnabled(bool value) async {
    notifyEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_enabled', value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keepNotify = prefs.getBool('notify_enabled') ?? true;
      final keepSubject = prefs.getString('wechat_subject');
      final keepAvatar = prefs.getString('avatar_custom_b64');
      await prefs.clear();
      await prefs.setBool('notify_enabled', keepNotify);
      if (keepSubject != null) await prefs.setString('wechat_subject', keepSubject);
      if (keepAvatar != null) await prefs.setString('avatar_custom_b64', keepAvatar);
    } catch (_) {}
  }

  Future<void> logout() async {
    token = null;
    displayName = null;
    authProvider = null;
    city = null;
    bio = null;
    phoneMasked = null;
    avatarId = 'orb';
    avatarBytes = null;
    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'display_name');
      await _storage.delete(key: 'auth_provider');
      await _storage.delete(key: 'profile_city');
      await _storage.delete(key: 'profile_bio');
      await _storage.delete(key: 'phone_masked');
      await _storage.delete(key: 'avatar_id');
    } catch (_) {}
    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthController>((ref) => AuthController());
