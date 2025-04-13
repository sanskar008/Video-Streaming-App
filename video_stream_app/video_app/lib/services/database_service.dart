import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'users.db');
    return await openDatabase(path, version: 1, onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE users(id INTEGER PRIMARY KEY, username TEXT, password TEXT)',
      );
    });
  }

  Future<User?> authenticate(String username, String password) async {
    final db = await database;
    final result = await db.query('users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password]);
    if (result.isNotEmpty) {
      return User(
          id: result[0]['id'] as int?,
          username: result[0]['username'] as String,
          password: result[0]['password'] as String);
    }
    return null;
  }

  Future<void> register(User user) async {
    final db = await database;
    await db.insert('users', user.toMap());
  }
}
