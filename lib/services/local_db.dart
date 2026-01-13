import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();
  static const _dbName = 'expense_splitter.db';
  static const _dbVersion = 2;

  Database? _database;

  Future<Database> get database async {
    final db = _database;
    if (db != null) return db;
    final newDb = await _initDb();
    _database = newDb;
    return newDb;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS expenses');
          await db.execute('DROP TABLE IF EXISTS group_members');
          await db.execute('DROP TABLE IF EXISTS groups');
          await db.execute('DROP TABLE IF EXISTS users');
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ownerId TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ownerId TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE group_members (
        groupId TEXT NOT NULL,
        userId TEXT NOT NULL,
        PRIMARY KEY (groupId, userId)
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        ownerId TEXT NOT NULL,
        groupId TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        payerId TEXT NOT NULL,
        participants TEXT NOT NULL,
        shares TEXT NOT NULL,
        splitMethod TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        pendingSync INTEGER NOT NULL
      )
    ''');
  }
}
