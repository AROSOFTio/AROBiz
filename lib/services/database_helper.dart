import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

/// Offline-only identity pending managed cloud authentication.
/// Uses PBKDF2-HMAC-SHA256; legacy SHA256 hashes are rehashed after login.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _iterations = 120000;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = kIsWeb ? 'arosoft_db.db' : join(await getDatabasesPath(), 'arosoft_db.db');
    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT,
          phone TEXT,
          passwordHash TEXT NOT NULL,
          businessName TEXT,
          businessCategory TEXT,
          location TEXT
        )
      ''');
    });
  }

  String _encodePassword(String password) {
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    return 'pbkdf2:$_iterations:${base64Url.encode(salt)}:${base64Url.encode(_pbkdf2(password, salt, _iterations))}';
  }

  List<int> _pbkdf2(String password, List<int> salt, int rounds) {
    final mac = Hmac(sha256, utf8.encode(password));
    var current = mac.convert([...salt, 0, 0, 0, 1]).bytes;
    final output = List<int>.from(current);
    for (var n = 1; n < rounds; n++) {
      current = mac.convert(current).bytes;
      for (var j = 0; j < output.length; j++) {
        output[j] ^= current[j];
      }
    }
    return output;
  }

  bool _constantTimeEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  bool _verifyPassword(String password, String stored) {
    if (!stored.startsWith('pbkdf2:')) {
      return _constantTimeEqual(
        utf8.encode(sha256.convert(utf8.encode(password)).toString()),
        utf8.encode(stored),
      );
    }
    final parts = stored.split(':');
    if (parts.length != 4) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 10000 || rounds > 1000000) return false;
    try {
      final salt = base64Url.decode(parts[2]);
      final expected = base64Url.decode(parts[3]);
      return _constantTimeEqual(_pbkdf2(password, salt, rounds), expected);
    } catch (_) {
      return false;
    }
  }

  Future<int> registerUser({
    required String identifier,
    required bool isEmail,
    required String password,
    required String businessName,
    required String category,
    required String location,
  }) async {
    if (password.length < 8) throw Exception('Password must be at least 8 characters');
    final db = await database;
    final id = identifier.trim().toLowerCase();
    if (id.isEmpty) throw Exception('Email or phone number required');
    final exists = await db.query('users',
      where: 'lower(email) = ? OR lower(phone) = ?', whereArgs: [id, id]);
    if (exists.isNotEmpty) throw Exception('Account already exists');
    return db.insert('users', {
      'email': isEmail ? id : null,
      'phone': isEmail ? null : id,
      'passwordHash': _encodePassword(password),
      'businessName': businessName,
      'businessCategory': category,
      'location': location,
    });
  }

  Future<Map<String, dynamic>?> loginUser(String identifier, String password) async {
    final db = await database;
    final id = identifier.trim().toLowerCase();
    final matches = await db.query('users',
      where: 'lower(email) = ? OR lower(phone) = ?', whereArgs: [id, id], limit: 1);
    if (matches.isEmpty) return null;
    final user = matches.first;
    final stored = user['passwordHash'] as String;
    if (!_verifyPassword(password, stored)) return null;
    if (!stored.startsWith('pbkdf2:')) {
      await db.update('users', {'passwordHash': _encodePassword(password)},
        where: 'id = ?', whereArgs: [user['id']]);
    }
    return user;
  }
}
