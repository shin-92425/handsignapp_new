import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// One saved recognition result.
class HistoryEntry {
  final int? id;

  /// Raw label from labels.txt, e.g. `open_palm`.
  final String label;

  /// 0.0 - 1.0
  final double confidence;

  final DateTime createdAt;

  /// `front` or `back`.
  final String camera;

  const HistoryEntry({
    this.id,
    required this.label,
    required this.confidence,
    required this.createdAt,
    required this.camera,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'confidence': confidence,
        'created_at': createdAt.millisecondsSinceEpoch,
        'camera': camera,
      };

  factory HistoryEntry.fromMap(Map<String, Object?> m) => HistoryEntry(
        id: m['id'] as int?,
        label: m['label'] as String,
        confidence: (m['confidence'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
        ),
        camera: (m['camera'] as String?) ?? 'front',
      );
}

/// SQLite storage for the recognition history.
class HistoryDb {
  HistoryDb._();

  static final HistoryDb instance = HistoryDb._();

  static const String _table = 'history';

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'hand_sign_history.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            created_at INTEGER NOT NULL,
            camera TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_history_created ON $_table(created_at DESC)',
        );
      },
    );

    _db = db;
    return db;
  }

  Future<int> insert(HistoryEntry entry) async {
    final db = await _database;
    return db.insert(_table, entry.toMap()..remove('id'));
  }

  /// Newest first.
  Future<List<HistoryEntry>> all({int limit = 500}) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete(_table);
  }
}
