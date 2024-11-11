import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
//import '../models/note_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;

  DBHelper._internal();

  static const String tableNotes = 'notes';
  static const int _version = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, 'mynotes.db');

    return await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT NOT NULL,
        priority INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for version 2
      await db.execute(
          'ALTER TABLE $tableNotes ADD COLUMN createdAt TEXT DEFAULT "${DateTime.now().toIso8601String()}"');
      await db.execute(
          'ALTER TABLE $tableNotes ADD COLUMN modifiedAt TEXT DEFAULT "${DateTime.now().toIso8601String()}"');
      await db.execute(
          'ALTER TABLE $tableNotes ADD COLUMN priority INTEGER DEFAULT 0');
    }
  }

  // Insert a new note
  Future<int> insertNote(Map<String, dynamic> note) async {
    final Database db = await database;
    return await db.insert(
      tableNotes,
      note,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all notes
  Future<List<Map<String, dynamic>>> getNotes() async {
    final Database db = await database;
    return await db.query(
      tableNotes,
      orderBy: 'modifiedAt DESC',
    );
  }

  // Get notes sorted by specific column
  Future<List<Map<String, dynamic>>> getNotesSortedBy(
    String column, {
    bool descending = true,
  }) async {
    final Database db = await database;
    return await db.query(
      tableNotes,
      orderBy: '$column ${descending ? 'DESC' : 'ASC'}',
    );
  }

  // Get a single note by id
  Future<Map<String, dynamic>?> getNoteById(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableNotes,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Update a note
  Future<int> updateNote(Map<String, dynamic> note, int id) async {
    final Database db = await database;
    return await db.update(
      tableNotes,
      note,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a note
  Future<int> deleteNote(int id) async {
    final Database db = await database;
    return await db.delete(
      tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete multiple notes
  Future<int> deleteNotes(List<int> ids) async {
    final Database db = await database;
    return await db.delete(
      tableNotes,
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  // Search notes
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final Database db = await database;
    return await db.query(
      tableNotes,
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'modifiedAt DESC',
    );
  }

  // Get notes by priority
  Future<List<Map<String, dynamic>>> getNotesByPriority(int priority) async {
    final Database db = await database;
    return await db.query(
      tableNotes,
      where: 'priority = ?',
      whereArgs: [priority],
      orderBy: 'modifiedAt DESC',
    );
  }

  // Update note priority
  Future<int> updateNotePriority(int id, int priority) async {
    final Database db = await database;
    return await db.update(
      tableNotes,
      {'priority': priority, 'modifiedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get total notes count
  Future<int> getNotesCount() async {
    final Database db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableNotes');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Delete all notes
  Future<int> deleteAllNotes() async {
    final Database db = await database;
    return await db.delete(tableNotes);
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
