import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

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

    String path;
    if (kIsWeb) {
      path = 'arosoft_db.db';
    } else {
      path = join(await getDatabasesPath(), 'arosoft_db.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
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
    
    // We can continue using SharedPreferences for invoices for simplicity,
    // or migrate them here. To keep the scope simple and focus on registration:
    // we use standard tables for new features.
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<int> registerUser({
    required String identifier,
    required bool isEmail,
    required String password,
    required String businessName,
    required String category,
    required String location,
  }) async {
    final db = await database;
    String pHash = _hashPassword(password);
    
    Map<String, dynamic> data = {
      'passwordHash': pHash,
      'businessName': businessName,
      'businessCategory': category,
      'location': location,
    };

    if (isEmail) {
      data['email'] = identifier;
      data['phone'] = null;
    } else {
      data['phone'] = identifier;
      data['email'] = null;
    }

    // Check if user exists
    final exists = await db.query(
      'users',
      where: 'email = ? OR phone = ?',
      whereArgs: [data['email'] ?? '', data['phone'] ?? ''],
    );
    
    if (exists.isNotEmpty) {
      throw Exception('User already exists with this email or phone.');
    }

    return await db.insert('users', data);
  }

  Future<Map<String, dynamic>?> loginUser(String identifier, String password) async {
    final db = await database;
    String pHash = _hashPassword(password);
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: '(email = ? OR phone = ?) AND passwordHash = ?',
      whereArgs: [identifier, identifier, pHash],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
