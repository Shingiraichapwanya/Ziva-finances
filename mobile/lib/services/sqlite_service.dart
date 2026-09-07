import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/sync_queue_item.dart';
import 'api_service.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._internal();
  static Database? _database;
  static bool _useMockFallback = false;

  final ApiService _api = ApiService();

  // In-memory mock storage fallback for web / unsupported SQLite environments
  final List<TransactionModel> _mockTransactions = [];
  final List<AccountModel> _mockAccounts = [];
  final List<SyncQueueItem> _mockQueue = [];

  SqliteService._internal();

  /// Invalidate and clear all in-memory and local caches so fresh queries
  /// strictly reflect the live, wiped BigQuery dataset.
  void invalidateAndClearCaches() {
    _mockTransactions.clear();
    _mockAccounts.clear();
    _mockQueue.clear();
    debugPrint('[SqliteService] Caches invalidated. Clean live state active.');
  }

  /// Public getter indicating if mock fallback is currently serving SQLite calls
  bool get isUsingMockFallback => kIsWeb || _useMockFallback;

  Future<Database?> get database async {
    // When running on web (kIsWeb), bypass sqflite entirely and directly route to BigQuery
    if (kIsWeb) return null;
    if (_database != null) return _database;
    if (_useMockFallback) return null;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) {
      debugPrint('[SqliteService] Running on Web (kIsWeb). Bypassing sqflite and directly routing queries to BigQuery service.');
      _useMockFallback = true;
      return null;
    }

    try {
      final dbPath = await getDatabasesPath();
      final dbFile = p.join(dbPath, 'ziva_finance.db');

      return await openDatabase(
        dbFile,
        version: 1,
        onCreate: (db, version) async {
          // 1. Local Transactions Cache
          await db.execute('''
            CREATE TABLE local_transactions (
              transaction_id TEXT PRIMARY KEY,
              transaction_date TEXT NOT NULL,
              account_id TEXT NOT NULL,
              category_id TEXT NOT NULL,
              category_name TEXT,
              transaction_type TEXT NOT NULL,
              original_amount REAL NOT NULL,
              original_currency TEXT NOT NULL,
              reporting_amount_zar REAL NOT NULL,
              reporting_amount_usd REAL NOT NULL,
              merchant_or_payee TEXT,
              payment_method TEXT,
              is_tax_deductible INTEGER NOT NULL DEFAULT 0,
              notes TEXT,
              tags TEXT,
              receipt_name TEXT,
              receipt_url TEXT,
              is_synced INTEGER NOT NULL DEFAULT 1,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          // 2. Offline Sync Mutation Queue
          await db.execute('''
            CREATE TABLE sync_queue (
              queue_id TEXT PRIMARY KEY,
              transaction_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              sync_status TEXT NOT NULL DEFAULT 'PENDING',
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            )
          ''');

          // 3. Local Accounts Cache
          await db.execute('''
            CREATE TABLE local_accounts (
              account_id TEXT PRIMARY KEY,
              account_name TEXT NOT NULL,
              financial_institution TEXT,
              country_code TEXT,
              primary_currency TEXT,
              cash_flow_tier TEXT,
              account_type TEXT,
              is_vault_locked INTEGER DEFAULT 0,
              withdrawal_notice_days INTEGER DEFAULT 0,
              account_number_masked TEXT,
              native_balance REAL NOT NULL,
              is_active INTEGER DEFAULT 1
            )
          ''');

          await db.execute('CREATE INDEX idx_tx_date ON local_transactions(transaction_date DESC)');
          await db.execute('CREATE INDEX idx_sync_status ON sync_queue(sync_status)');
        },
      );
    } catch (e) {
      debugPrint('[SqliteService] Database initialization failed: $e. Falling back to clean in-memory mock store.');
      _useMockFallback = true;
      return null;
    }
  }

  // --- Transactions ---

  Future<void> saveTransaction(TransactionModel tx) async {
    if (kIsWeb) {
      // In web mode, route directly to BigQuery service and update in-memory cache
      _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
      _mockTransactions.insert(0, tx);
      try {
        final res = await _api.postTransaction(tx.toJson());
        if (res['success'] == true) {
          await markTransactionSynced(tx.transactionId);
          debugPrint('[SqliteService] Web: Transaction ${tx.transactionId} posted directly to BigQuery.');
        }
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery post failed: $e (stored locally in memory)');
      }
      return;
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
      _mockTransactions.insert(0, tx);
      return;
    }
    await db.insert(
      'local_transactions',
      tx.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTransactionsBatch(List<TransactionModel> list) async {
    if (kIsWeb || _useMockFallback) {
      for (final tx in list) {
        _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
        _mockTransactions.add(tx);
      }
      return;
    }
    final db = await database;
    if (db == null) {
      for (final tx in list) {
        _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
        _mockTransactions.add(tx);
      }
      return;
    }
    final batch = db.batch();
    for (final tx in list) {
      batch.insert(
        'local_transactions',
        tx.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Fetches transactions. On web (kIsWeb), directly routes to BigQuery service.
  Future<List<TransactionModel>> getTransactions({int limit = 100}) async {
    if (kIsWeb) {
      try {
        final bqTxs = await _api.fetchTransactions(limit: limit);
        _mockTransactions.clear();
        if (bqTxs.isNotEmpty) {
          _mockTransactions.addAll(bqTxs);
          debugPrint('[SqliteService] Web: Successfully retrieved ${bqTxs.length} ledger transactions directly from BigQuery.');
        } else {
          debugPrint('[SqliteService] Web: Live BigQuery transaction table has 0 rows.');
        }
        return bqTxs;
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery fetch failed: $e. Returning empty list.');
        return [];
      }
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      final sorted = List<TransactionModel>.from(_mockTransactions)
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return sorted.take(limit).toList();
    }
    final result = await db.query(
      'local_transactions',
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromJson(map)).toList();
  }

  Future<void> markTransactionSynced(String transactionId) async {
    if (kIsWeb || _useMockFallback) {
      final idx = _mockTransactions.indexWhere((t) => t.transactionId == transactionId);
      if (idx != -1) {
        final old = _mockTransactions[idx];
        _mockTransactions[idx] = TransactionModel(
          transactionId: old.transactionId,
          transactionDate: old.transactionDate,
          accountId: old.accountId,
          categoryId: old.categoryId,
          categoryName: old.categoryName,
          transactionType: old.transactionType,
          originalAmount: old.originalAmount,
          originalCurrency: old.originalCurrency,
          reportingAmountZar: old.reportingAmountZar,
          reportingAmountUsd: old.reportingAmountUsd,
          merchantOrPayee: old.merchantOrPayee,
          paymentMethod: old.paymentMethod,
          isTaxDeductible: old.isTaxDeductible,
          notes: old.notes,
          tags: old.tags,
          isSynced: true,
        );
      }
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.update(
      'local_transactions',
      {'is_synced': 1},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Deletes a transaction from BigQuery and local stores
  Future<bool> deleteTransaction(String transactionId) async {
    // 1. Immediately prune from in-memory cache
    _mockTransactions.removeWhere((t) => t.transactionId == transactionId);

    if (kIsWeb) {
      try {
        final success = await _api.deleteTransaction(transactionId);
        debugPrint('[SqliteService] Web: Successfully deleted transaction $transactionId from BigQuery.');
        return success;
      } catch (e) {
        debugPrint('[SqliteService] Web: BigQuery delete call failed: $e (pruned from local session).');
        return true;
      }
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      return true;
    }

    // 2. Delete from local SQLite table
    await db.delete(
      'local_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    // 3. Delete from BigQuery directly if online, or enqueue deletion mutation
    try {
      await _api.deleteTransaction(transactionId);
    } catch (_) {
      await enqueueMutation(
        transactionId: transactionId,
        payloadJson: jsonEncode({'action': 'DELETE', 'transactionId': transactionId}),
      );
    }
    return true;
  }

  // --- Sync Queue ---

  Future<SyncQueueItem> enqueueMutation({
    required String transactionId,
    required String payloadJson,
  }) async {
    final queueItem = SyncQueueItem(
      queueId: const Uuid().v4(),
      transactionId: transactionId,
      payloadJson: payloadJson,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      syncStatus: SyncStatus.pending,
      retryCount: 0,
    );

    if (kIsWeb) {
      // In web mode, attempt direct sync immediately
      try {
        final Map<String, dynamic> payload =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final res = await _api.postTransaction(payload);
        if (res['success'] == true) {
          await markTransactionSynced(transactionId);
          return queueItem.copyWith(syncStatus: SyncStatus.synced);
        }
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery mutation push failed: $e (queued in memory)');
      }
      _mockQueue.removeWhere((item) => item.transactionId == transactionId);
      _mockQueue.add(queueItem);
      return queueItem;
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      _mockQueue.removeWhere((item) => item.transactionId == transactionId);
      _mockQueue.add(queueItem);
      return queueItem;
    }

    await db.insert(
      'sync_queue',
      queueItem.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return queueItem;
  }

  Future<List<SyncQueueItem>> getPendingQueue() async {
    if (kIsWeb || _useMockFallback) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .toList();
    }
    final db = await database;
    if (db == null) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .toList();
    }
    final result = await db.query(
      'sync_queue',
      where: "sync_status IN ('PENDING', 'FAILED')",
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SyncQueueItem.fromSqlite(map)).toList();
  }

  Future<List<SyncQueueItem>> getAllQueueItems() async {
    if (kIsWeb || _useMockFallback) {
      return List<SyncQueueItem>.from(_mockQueue);
    }
    final db = await database;
    if (db == null) return List<SyncQueueItem>.from(_mockQueue);
    final result = await db.query(
      'sync_queue',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => SyncQueueItem.fromSqlite(map)).toList();
  }

  Future<void> updateQueueItem(SyncQueueItem item) async {
    if (kIsWeb || _useMockFallback) {
      final idx = _mockQueue.indexWhere((q) => q.queueId == item.queueId);
      if (idx != -1) {
        _mockQueue[idx] = item;
      }
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.update(
      'sync_queue',
      item.toSqliteMap(),
      where: 'queue_id = ?',
      whereArgs: [item.queueId],
    );
  }

  Future<int> getPendingQueueCount() async {
    if (kIsWeb || _useMockFallback) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .length;
    }
    final db = await database;
    if (db == null) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .length;
    }
    final count = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(1) FROM sync_queue WHERE sync_status IN ('PENDING', 'FAILED')",
    ));
    return count ?? 0;
  }

  Future<void> clearCompletedQueue() async {
    if (kIsWeb || _useMockFallback) {
      _mockQueue.removeWhere((item) => item.syncStatus == SyncStatus.synced);
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.delete('sync_queue', where: "sync_status = 'SYNCED'");
  }

  // --- Accounts ---

  Future<void> saveAccountsBatch(List<AccountModel> accounts) async {
    if (kIsWeb || _useMockFallback) {
      for (final acc in accounts) {
        _mockAccounts.removeWhere((a) => a.accountId == acc.accountId);
        _mockAccounts.add(acc);
      }
      return;
    }
    final db = await database;
    if (db == null) {
      for (final acc in accounts) {
        _mockAccounts.removeWhere((a) => a.accountId == acc.accountId);
        _mockAccounts.add(acc);
      }
      return;
    }
    final batch = db.batch();
    for (final acc in accounts) {
      batch.insert(
        'local_accounts',
        acc.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Fetches accounts. On web (kIsWeb), directly routes to BigQuery service.
  Future<List<AccountModel>> getLocalAccounts() async {
    if (kIsWeb) {
      try {
        final bqAccounts = await _api.fetchAccounts();
        _mockAccounts.clear();
        if (bqAccounts.isNotEmpty) {
          _mockAccounts.addAll(bqAccounts);
          debugPrint('[SqliteService] Web: Successfully retrieved ${bqAccounts.length} accounts directly from BigQuery.');
        } else {
          debugPrint('[SqliteService] Web: Live BigQuery accounts table has 0 rows.');
        }
        return bqAccounts.where((a) => a.isActive).toList();
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery accounts fetch failed: $e. Returning empty list.');
        return [];
      }
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      return _mockAccounts.where((a) => a.isActive).toList();
    }
    final result = await db.query('local_accounts', where: 'is_active = 1');
    return result.map((m) => AccountModel.fromJson(m)).toList();
  }
}
