import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SkillverseCloud {
  SkillverseCloud._(this.client, this._storage);

  final SupabaseClient client;
  final _SessionStorage _storage;

  static Future<SkillverseCloud?> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty && key.isEmpty) return null;
    if (Uri.tryParse(url)?.scheme != 'https' ||
        !key.startsWith('sb_publishable_')) {
      throw StateError('Configure an HTTPS Supabase URL and publishable key.');
    }
    final storage = _SessionStorage(url);
    final supabase = await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: FlutterAuthClientOptions(
        localStorage: storage,
        detectSessionInUri: false,
      ),
    );
    return SkillverseCloud._(supabase.client, storage);
  }

  Future<bool> signUp(String name, String email, String password) async {
    _storage.remember = false;
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
      emailRedirectTo:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'com.learningapp.learningapp://auth/confirmed'
          : null,
    );
    final requiresConfirmation = response.session == null;
    if (!requiresConfirmation) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
    return requiresConfirmation;
  }

  Future<User?> signIn(String email, String password, bool remember) async {
    _storage.remember = remember;
    return (await client.auth.signInWithPassword(
      email: email,
      password: password,
    )).user;
  }

  Future<void> changePassword(
    String email,
    String oldPassword,
    String password,
  ) async {
    _storage.remember = false;
    await client.auth.signInWithPassword(email: email, password: oldPassword);
    try {
      await client.auth.updateUser(
        UserAttributes(password: password, currentPassword: oldPassword),
      );
    } finally {
      await client.auth.signOut(scope: SignOutScope.local);
    }
  }

  Future<void> submitResult(
    String ownerId,
    String source,
    Map<String, dynamic> answers,
  ) async {
    await client
        .rpc<void>(
          'skillverse_submit_result',
          params: {
            'expected_user': ownerId,
            'result_source': source,
            'answers': answers,
          },
        )
        .timeout(const Duration(seconds: 12));
  }

  Future<List<LeaderboardEntry>> leaderboard(String period) async {
    final rows = await client
        .rpc<List<dynamic>>(
          'skillverse_leaderboard',
          params: {'requested_period': period},
        )
        .timeout(const Duration(seconds: 12));
    return rows.map((row) {
      final json = row as Map<String, dynamic>;
      return LeaderboardEntry(
        name: json['full_name'] as String? ?? '',
        points: json['points'] as int,
        rank: json['rank'] as int?,
        isYou: json['is_you'] as bool,
      );
    }).toList();
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.points,
    required this.rank,
    required this.isYou,
  });

  final String name;
  final int points;
  final int? rank;
  final bool isYou;
}

class _SessionStorage extends LocalStorage {
  _SessionStorage(String url) : _key = 'skillverse.cloud.session.$url';

  final String _key;
  late final SharedPreferences _prefs;
  bool remember = false;

  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    remember = _prefs.containsKey(_key);
  }

  @override
  Future<bool> hasAccessToken() async => remember && _prefs.containsKey(_key);

  @override
  Future<String?> accessToken() async =>
      remember ? _prefs.getString(_key) : null;

  @override
  Future<void> removePersistedSession() async {
    await _prefs.remove(_key);
  }

  @override
  Future<void> persistSession(String value) async {
    if (remember) await _prefs.setString(_key, value);
  }
}
