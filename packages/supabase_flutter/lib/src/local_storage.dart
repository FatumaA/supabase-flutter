import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hiveBoxName = 'supabase_authentication';
const supabasePersistSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

/// LocalStorage is used to persist the user session in the device.
///
/// See also:
///
///   * [SupabaseAuth], the instance used to manage authentication
///   * [EmptyLocalStorage], used to disable session persistence
///   * [HiveLocalStorage], that implements Hive as storage method
abstract class LocalStorage {
  const LocalStorage({
    required this.initialize,
    required this.hasAccessToken,
    required this.accessToken,
    required this.persistSession,
    required this.removePersistedSession,
  });

  /// Initialize the storage to persist session.
  final Future<void> Function() initialize;

  /// Check if there is a persisted session.
  final Future<bool> Function() hasAccessToken;

  /// Get the access token from the current persisted session.
  final Future<String?> Function() accessToken;

  /// Remove the current persisted session.
  final Future<void> Function() removePersistedSession;

  /// Persist a session in the device.
  final Future<void> Function(String) persistSession;
}

/// A [LocalStorage] implementation that does nothing. Use this to
/// disable persistence.
class EmptyLocalStorage extends LocalStorage {
  /// Creates a [LocalStorage] instance that disables persistence
  const EmptyLocalStorage()
      : super(
          initialize: _initialize,
          hasAccessToken: _hasAccessToken,
          accessToken: _accessToken,
          removePersistedSession: _removePersistedSession,
          persistSession: _persistSession,
        );

  static Future<void> _initialize() async {}
  static Future<bool> _hasAccessToken() => Future.value(false);
  static Future<String?> _accessToken() => Future.value();
  static Future<void> _removePersistedSession() async {}
  static Future<void> _persistSession(_) async {}
}

/// A [LocalStorage] implementation that implements Hive as the
/// storage method.
class HiveLocalStorage extends LocalStorage {
  /// Creates a LocalStorage instance that implements the Hive Database
  const HiveLocalStorage()
      : super(
          initialize: _initialize,
          hasAccessToken: _hasAccessToken,
          accessToken: _accessToken,
          removePersistedSession: _removePersistedSession,
          persistSession: _persistSession,
        );

  /// The encryption key used by Hive. If null, the box is not encrypted
  ///
  /// This value should not be redefined in runtime, otherwise the user may
  /// not be fetched correctly
  ///
  /// See also:
  ///
  ///   * <https://docs.hivedb.dev/#/advanced/encrypted_box?id=encrypted-box>
  static String? encryptionKey;

  static Future<void> _initialize() async {
    HiveCipher? encryptionCipher;
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(base64Url.decode(encryptionKey!));
    }
    await Hive.initFlutter('auth');
    await Hive.openBox(_hiveBoxName, encryptionCipher: encryptionCipher);
  }

  static Future<bool> _hasAccessToken() {
    return Future.value(
      Hive.box(_hiveBoxName).containsKey(
        supabasePersistSessionKey,
      ),
    );
  }

  static Future<String?> _accessToken() {
    return Future.value(
      Hive.box(_hiveBoxName).get(supabasePersistSessionKey) as String?,
    );
  }

  static Future<void> _removePersistedSession() {
    return Hive.box(_hiveBoxName).delete(supabasePersistSessionKey);
  }

  static Future<void> _persistSession(String persistSessionString) {
    // Flush after X amount of writes
    return Hive.box(_hiveBoxName)
        .put(supabasePersistSessionKey, persistSessionString);
  }
}

/// local storage to store pkce flow code verifier.
class SharedPreferencesGotrueAsyncStorage extends GotrueAsyncStorage {
  SharedPreferencesGotrueAsyncStorage() {
    _initialize();
  }

  final Completer<void> _initializationCompleter = Completer();

  late final SharedPreferences _prefs;

  Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    _prefs = await SharedPreferences.getInstance();
    _initializationCompleter.complete();
  }

  @override
  Future<String?> getItem({required String key}) async {
    await _initializationCompleter.future;
    return _prefs.getString(key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _initializationCompleter.future;
    await _prefs.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _initializationCompleter.future;
    await _prefs.setString(key, value);
  }
}
