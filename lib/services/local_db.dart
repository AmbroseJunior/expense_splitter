import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();
  static const _dbName = 'expense_splitter.db';
  static const _dbVersion = 1;

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
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      },
    );
  }
}
