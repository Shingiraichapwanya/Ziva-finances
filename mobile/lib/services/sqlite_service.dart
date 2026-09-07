import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/asset_model.dart';
import '../models/debt_model.dart';
import '../models/envelope_model.dart';
import '../models/sync_queue_item.dart';
import '../models/transaction_model.dart';
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
  final List<EnvelopeModel> _mockEnvelopes = [];
  final List<AssetModel> _mockAssets = [];
  final List<DebtModel> _mockDebts = [];

  static final List<AssetModel> defaultAssets = [
    AssetModel(
      id: 'ASSET_REAL_ESTATE_01',
      name: 'Camps Bay Ocean Villa',
      type: AssetType.tangible,
      category: AssetCategory.realEstate,
      currentValueZar: 14200000.0,
      acquisitionCostZar: 12500000.0,
      acquisitionDate: DateTime(2022, 3, 15),
      depreciationMethod: DepreciationMethod.straightLine,
      usefulLifeYears: 30.0,
      depreciationRatePercent: 3.33,
      location: 'Camps Bay, Cape Town (Western Cape)',
      registrationNumber: 'Deed T90210/2022',
      documentationReference: 'Old Mutual Insure Policy #ZA-CPT-9921',
      ownershipType: OwnershipType.solo,
      myOwnershipPercentage: 100.0,
      partnerOwnershipPercentage: 0.0,
      notes: 'Luxury residential primary holding with uninterrupted Atlantic views',
      includeInNetWorth: true,
      createdAt: DateTime(2022, 3, 15),
      updatedAt: DateTime.now(),
    ),
    AssetModel(
      id: 'ASSET_VEHICLE_01',
      name: 'Porsche 911 GT3 (992)',
      type: AssetType.tangible,
      category: AssetCategory.vehicle,
      currentValueZar: 2950000.0,
      acquisitionCostZar: 3200000.0,
      acquisitionDate: DateTime(2023, 6, 10),
      depreciationMethod: DepreciationMethod.reducingBalance,
      usefulLifeYears: 5.0,
      depreciationRatePercent: 15.0,
      location: 'Private Garage, Camps Bay',
      registrationNumber: 'CA 911-ZAR',
      documentationReference: 'Discovery Insure Comprehensive #DISC-VEH-4412',
      ownershipType: OwnershipType.solo,
      myOwnershipPercentage: 100.0,
      partnerOwnershipPercentage: 0.0,
      linkedLiabilityId: 'DEBT_VEHICLE_FINANCE',
      linkedLiabilityName: 'FNB Asset Finance (Porsche 911)',
      linkedLiabilityAmountZar: 1100000.0,
      notes: 'High-performance GT vehicle held under asset finance schedule',
      includeInNetWorth: true,
      createdAt: DateTime(2023, 6, 10),
      updatedAt: DateTime.now(),
    ),
    AssetModel(
      id: 'ASSET_IP_ALGO_01',
      name: 'Antigravity AI Quantitative Algorithm',
      type: AssetType.intangible,
      category: AssetCategory.ipPatent,
      currentValueZar: 8000000.0,
      acquisitionCostZar: 4500000.0,
      acquisitionDate: DateTime(2024, 1, 20),
      depreciationMethod: DepreciationMethod.amortization,
      usefulLifeYears: 10.0,
      depreciationRatePercent: 10.0,
      location: 'GCP Cloud Vault & GitHub Enterprise',
      registrationNumber: 'Patent Filing ZA2026/00192',
      documentationReference: 'IP Assignment Deed & Syndicate Escrow',
      ownershipType: OwnershipType.joint,
      myOwnershipPercentage: 70.0,
      partnerOwnershipPercentage: 30.0,
      notes: 'Proprietary automated liquidity routing and forecasting engine',
      includeInNetWorth: true,
      createdAt: DateTime(2024, 1, 20),
      updatedAt: DateTime.now(),
    ),
    AssetModel(
      id: 'ASSET_CRYPTO_01',
      name: 'Bitcoin Treasury Reserve (BTC Cold Vault)',
      type: AssetType.intangible,
      category: AssetCategory.digitalAsset,
      currentValueZar: 1850000.0,
      acquisitionCostZar: 1200000.0,
      acquisitionDate: DateTime(2023, 11, 5),
      depreciationMethod: DepreciationMethod.none,
      usefulLifeYears: 0.0,
      depreciationRatePercent: 0.0,
      location: 'Multisig Ledger Hardware Vault (Offline Custody)',
      registrationNumber: 'xpub6D4B...vault-01',
      documentationReference: 'Custody Vault Protocol v2.1',
      ownershipType: OwnershipType.solo,
      myOwnershipPercentage: 100.0,
      partnerOwnershipPercentage: 0.0,
      notes: 'Strategic institutional inflation hedge in multi-sig custody',
      includeInNetWorth: true,
      createdAt: DateTime(2023, 11, 5),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<DebtModel> defaultDebts = [
    DebtModel(
      id: 'DEBT_VEHICLE_FINANCE',
      counterparty: 'FNB Asset Finance (WesBank)',
      direction: DebtDirection.owedByMe,
      debtType: DebtType.assetFinance,
      originalPrincipalZar: 1800000.0,
      currentOutstandingBalanceZar: 1100000.0,
      currency: 'ZAR',
      interestRatePercent: 11.75,
      minimumMonthlyPaymentZar: 34500.0,
      dueDate: DateTime.now().add(const Duration(days: 8)),
      linkedEnvelopeId: 'CAT_SINKING_MAINTENANCE',
      linkedEnvelopeName: 'Vehicle Maintenance & Insurance Sinking Fund',
      status: DebtStatus.current,
      notes: 'Porsche 911 GT3 structured commercial installment sale',
      repayments: [
        DebtRepaymentModel(
          id: 'REP_VEH_01',
          debtId: 'DEBT_VEHICLE_FINANCE',
          amountZar: 34500.0,
          paymentDate: DateTime.now().subtract(const Duration(days: 22)),
          paymentMethod: 'FNB Debit Order',
          sourceEnvelopeId: 'CAT_SINKING_MAINTENANCE',
          sourceEnvelopeName: 'Vehicle Maintenance & Insurance Sinking Fund',
          notes: 'Scheduled monthly installment',
          createdAt: DateTime.now().subtract(const Duration(days: 22)),
        ),
      ],
      createdAt: DateTime(2023, 6, 10),
      updatedAt: DateTime.now(),
    ),
    DebtModel(
      id: 'DEBT_DISCOVERY_CARD',
      counterparty: 'Discovery Bank Corporate Credit',
      direction: DebtDirection.owedByMe,
      debtType: DebtType.creditCard,
      originalPrincipalZar: 150000.0,
      currentOutstandingBalanceZar: 38500.0,
      currency: 'ZAR',
      interestRatePercent: 14.5,
      minimumMonthlyPaymentZar: 8500.0,
      dueDate: DateTime.now().add(const Duration(days: 20)),
      linkedEnvelopeId: 'CAT_TECH_CLOUD',
      linkedEnvelopeName: 'Cloud SaaS & Productivity Tools',
      status: DebtStatus.current,
      notes: 'Operational revolving cloud and travel card',
      repayments: [],
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime.now(),
    ),
    DebtModel(
      id: 'CREDIT_VENTURE_ADVANCE',
      counterparty: 'Kudzai Chimwaza (Syndicated Venture)',
      direction: DebtDirection.owedToMe,
      debtType: DebtType.personalLoan,
      originalPrincipalZar: 450000.0,
      currentOutstandingBalanceZar: 280000.0,
      currency: 'ZAR',
      interestRatePercent: 8.5,
      minimumMonthlyPaymentZar: 35000.0,
      dueDate: DateTime.now().add(const Duration(days: 14)),
      status: DebtStatus.current,
      notes: 'Working capital bridge facility for African tech venture round',
      repayments: [
        DebtRepaymentModel(
          id: 'REP_KUD_01',
          debtId: 'CREDIT_VENTURE_ADVANCE',
          amountZar: 170000.0,
          paymentDate: DateTime.now().subtract(const Duration(days: 35)),
          paymentMethod: 'EFT Wire',
          notes: 'Tranche 1 repayment received',
          createdAt: DateTime.now().subtract(const Duration(days: 35)),
        ),
      ],
      createdAt: DateTime(2025, 10, 1),
      updatedAt: DateTime.now(),
    ),
    DebtModel(
      id: 'CREDIT_APEX_INVOICE',
      counterparty: 'Apex Enterprise Consulting Ltd',
      direction: DebtDirection.owedToMe,
      debtType: DebtType.invoiceReceivable,
      originalPrincipalZar: 185000.0,
      currentOutstandingBalanceZar: 185000.0,
      currency: 'ZAR',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      status: DebtStatus.current,
      notes: 'Q1 Executive Advisory and AI architecture advisory retainer',
      repayments: [],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<EnvelopeModel> defaultEnvelopes = [
    const EnvelopeModel(
      categoryId: 'CAT_HOUSING_RENT',
      categoryName: 'Residential Rent & Levies',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 18500.0,
      actualSpentZar: 0.0,
      isFixedObligation: true,
      notes: 'Primary residence monthly lease and building levies',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_GROCERIES',
      categoryName: 'Groceries & Household',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmountZar: 6500.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Food markets, Woolworths, and household essentials',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_UTILITIES',
      categoryName: 'Electricity & Municipal Utilities',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 2200.0,
      actualSpentZar: 0.0,
      isFixedObligation: true,
      notes: 'Eskom prepaid electricity and municipal water',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_CONNECTIVITY',
      categoryName: 'Fibre Internet & Mobile Data',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 1450.0,
      actualSpentZar: 0.0,
      isFixedObligation: true,
      notes: 'High-speed home fibre and roaming mobile eSIM data',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_DINING_LEISURE',
      categoryName: 'Dining, Coffee & Social',
      categoryGroup: 'DISCRETIONARY',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmountZar: 3500.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Client dinners, coffee meetings, and personal leisure',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_TECH_CLOUD',
      categoryName: 'Cloud SaaS & Productivity Tools',
      categoryGroup: 'DISCRETIONARY',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmountZar: 2800.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'GitHub, Google Cloud, AI tools, and productivity suites',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_SINKING_EMERGENCY',
      categoryName: 'Emergency Reserve Sinking Fund',
      categoryGroup: 'SINKING_FUNDS',
      cashFlowTier: 'LONG_TERM_VAULT',
      targetCurrency: 'ZAR',
      plannedAmountZar: 5000.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Monthly allocation towards 6-month liquid emergency runway',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_SINKING_MAINTENANCE',
      categoryName: 'Vehicle Maintenance & Insurance Sinking Fund',
      categoryGroup: 'SINKING_FUNDS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 2500.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Tyres, annual vehicle servicing, and comprehensive cover',
    ),
  ];

  SqliteService._internal() {
    _ensureDefaultData();
  }

  void _ensureDefaultData() {
    if (_mockEnvelopes.isEmpty) {
      _mockEnvelopes.addAll(defaultEnvelopes);
    }
    if (_mockAssets.isEmpty) {
      _mockAssets.addAll(defaultAssets);
    }
    if (_mockDebts.isEmpty) {
      _mockDebts.addAll(defaultDebts);
    }
  }

  void _ensureDefaultEnvelopes() {
    _ensureDefaultData();
  }

  /// Invalidate and clear all in-memory and local caches so fresh queries
  /// strictly reflect the live, wiped BigQuery dataset.
  void invalidateAndClearCaches() {
    _mockTransactions.clear();
    _mockAccounts.clear();
    _mockQueue.clear();
    _mockEnvelopes.clear();
    _mockAssets.clear();
    _mockDebts.clear();
    _ensureDefaultData();
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
    // Automatically apply to local envelope balances
    applyTransactionToEnvelopes(tx);

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
    // 1. Immediately prune from in-memory cache and revert envelope balances
    final idx = _mockTransactions.indexWhere((t) => t.transactionId == transactionId);
    if (idx != -1) {
      final tx = _mockTransactions[idx];
      applyTransactionToEnvelopes(tx, isRevert: true);
      _mockTransactions.removeAt(idx);
    } else {
      _mockTransactions.removeWhere((t) => t.transactionId == transactionId);
    }

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

  // --- Envelope Budget Management ---

  /// Retrieve all active budget envelopes
  Future<List<EnvelopeModel>> getEnvelopes() async {
    _ensureDefaultEnvelopes();
    return List<EnvelopeModel>.from(_mockEnvelopes.where((e) => e.isActive));
  }

  /// Create or update an envelope
  Future<void> saveEnvelope(EnvelopeModel envelope) async {
    _ensureDefaultEnvelopes();
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == envelope.categoryId);
    if (idx != -1) {
      _mockEnvelopes[idx] = envelope;
    } else {
      _mockEnvelopes.add(envelope);
    }
  }

  /// Archive/deactivate an envelope
  Future<void> archiveEnvelope(String categoryId) async {
    _ensureDefaultEnvelopes();
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == categoryId);
    if (idx != -1) {
      _mockEnvelopes[idx] = _mockEnvelopes[idx].copyWith(isActive: false);
    }
  }

  /// Move/transfer funds between two envelopes
  Future<void> transferFunds({
    required String fromCategoryId,
    required String toCategoryId,
    required double amount,
  }) async {
    _ensureDefaultEnvelopes();
    if (amount <= 0) return;

    final fromIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == fromCategoryId);
    final toIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == toCategoryId);

    if (fromIdx != -1 && toIdx != -1) {
      final fromEnv = _mockEnvelopes[fromIdx];
      final toEnv = _mockEnvelopes[toIdx];

      _mockEnvelopes[fromIdx] = fromEnv.copyWith(
        plannedAmountZar: (fromEnv.plannedAmountZar - amount).clamp(0.0, double.infinity),
      );
      _mockEnvelopes[toIdx] = toEnv.copyWith(
        plannedAmountZar: toEnv.plannedAmountZar + amount,
      );
    }
  }

  /// Top up an envelope's planned allocation
  Future<void> topUpEnvelope(String categoryId, double amount) async {
    _ensureDefaultEnvelopes();
    if (amount <= 0) return;
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == categoryId);
    if (idx != -1) {
      final env = _mockEnvelopes[idx];
      _mockEnvelopes[idx] = env.copyWith(
        plannedAmountZar: env.plannedAmountZar + amount,
      );
    }
  }

  /// Reduce an envelope's planned allocation
  Future<void> reduceEnvelope(String categoryId, double amount) async {
    _ensureDefaultEnvelopes();
    if (amount <= 0) return;
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == categoryId);
    if (idx != -1) {
      final env = _mockEnvelopes[idx];
      _mockEnvelopes[idx] = env.copyWith(
        plannedAmountZar: (env.plannedAmountZar - amount).clamp(0.0, double.infinity),
      );
    }
  }

  /// Immediate optimistic reflection of transaction in envelope spent amounts
  void applyTransactionToEnvelopes(TransactionModel tx, {bool isRevert = false}) {
    _ensureDefaultEnvelopes();
    if (tx.categoryId.isEmpty) return;

    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == tx.categoryId);
    if (idx != -1) {
      final env = _mockEnvelopes[idx];
      final spendDelta = tx.reportingAmountZar.abs();
      final newSpent = isRevert
          ? (env.actualSpentZar - spendDelta).clamp(0.0, double.infinity)
          : env.actualSpentZar + spendDelta;

      _mockEnvelopes[idx] = env.copyWith(actualSpentZar: newSpent);
    }
  }

  // =========================================================================
  // ASSET REGISTRY & MANAGER METHODS
  // =========================================================================

  /// Fetch all active assets
  Future<List<AssetModel>> getAssets() async {
    _ensureDefaultData();
    return List<AssetModel>.from(_mockAssets);
  }

  /// Save or update an asset
  Future<void> saveAsset(AssetModel asset) async {
    _ensureDefaultData();
    final idx = _mockAssets.indexWhere((a) => a.id == asset.id);
    if (idx != -1) {
      _mockAssets[idx] = asset;
    } else {
      _mockAssets.insert(0, asset);
    }
  }

  /// Delete an asset
  Future<void> deleteAsset(String id) async {
    _ensureDefaultData();
    _mockAssets.removeWhere((a) => a.id == id);
  }

  /// Total gross valuation of all assets
  double getTotalAssetsValueZar() {
    _ensureDefaultData();
    return _mockAssets.fold<double>(0.0, (sum, a) => sum + a.currentValueZar);
  }

  /// Total net book value (cost - depreciation) of all assets
  double getTotalAssetsNetBookValueZar() {
    _ensureDefaultData();
    return _mockAssets.fold<double>(0.0, (sum, a) => sum + a.netBookValueZar);
  }

  /// Net equity contribution of all included assets to Net Worth
  double getTotalAssetsNetWorthContributionZar() {
    _ensureDefaultData();
    return _mockAssets.fold<double>(0.0, (sum, a) => sum + a.effectiveNetWorthContributionZar);
  }

  // =========================================================================
  // DEBT & CREDIT LEDGER METHODS
  // =========================================================================

  /// Fetch all debts and credits
  Future<List<DebtModel>> getDebts({DebtDirection? direction}) async {
    _ensureDefaultData();
    if (direction != null) {
      return _mockDebts.where((d) => d.direction == direction).toList();
    }
    return List<DebtModel>.from(_mockDebts);
  }

  /// Save or update a debt/credit entry
  Future<void> saveDebt(DebtModel debt) async {
    _ensureDefaultData();
    final idx = _mockDebts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) {
      _mockDebts[idx] = debt;
    } else {
      _mockDebts.insert(0, debt);
    }
  }

  /// Delete a debt/credit entry
  Future<void> deleteDebt(String id) async {
    _ensureDefaultData();
    _mockDebts.removeWhere((d) => d.id == id);
  }

  /// Record a repayment / settlement event against a debt record
  Future<DebtModel?> recordDebtRepayment({
    required String debtId,
    required double amountZar,
    required String paymentMethod,
    String? sourceEnvelopeId,
    String notes = '',
    DateTime? paymentDate,
  }) async {
    _ensureDefaultData();
    final idx = _mockDebts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return null;

    final debt = _mockDebts[idx];
    final payDate = paymentDate ?? DateTime.now();
    final newBalance = (debt.currentOutstandingBalanceZar - amountZar).clamp(0.0, double.infinity);
    final isFullyPaid = newBalance <= 0.01;

    final repayment = DebtRepaymentModel(
      id: 'REP_${DateTime.now().millisecondsSinceEpoch}',
      debtId: debtId,
      amountZar: amountZar,
      paymentDate: payDate,
      paymentMethod: paymentMethod,
      sourceEnvelopeId: sourceEnvelopeId,
      sourceEnvelopeName: sourceEnvelopeId != null
          ? _mockEnvelopes.firstWhere((e) => e.categoryId == sourceEnvelopeId, orElse: () => _mockEnvelopes.first).categoryName
          : null,
      notes: notes,
      createdAt: DateTime.now(),
    );

    final updatedRepayments = List<DebtRepaymentModel>.from(debt.repayments)..insert(0, repayment);

    final updatedDebt = debt.copyWith(
      currentOutstandingBalanceZar: newBalance,
      status: isFullyPaid ? DebtStatus.paidOff : debt.status,
      repayments: updatedRepayments,
    );

    _mockDebts[idx] = updatedDebt;

    // Optimistically deduct from linked/source envelope if specified
    if (sourceEnvelopeId != null && amountZar > 0) {
      final envIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == sourceEnvelopeId);
      if (envIdx != -1) {
        final env = _mockEnvelopes[envIdx];
        _mockEnvelopes[envIdx] = env.copyWith(
          actualSpentZar: env.actualSpentZar + amountZar,
        );
      }
    }

    // Also deduct linked liability from linked asset if any
    final assetIdx = _mockAssets.indexWhere((a) => a.linkedLiabilityId == debtId);
    if (assetIdx != -1) {
      final asset = _mockAssets[assetIdx];
      final newLiab = (asset.linkedLiabilityAmountZar - amountZar).clamp(0.0, double.infinity);
      _mockAssets[assetIdx] = asset.copyWith(linkedLiabilityAmountZar: newLiab);
    }

    return updatedDebt;
  }

  /// Full payoff Settle Up action
  Future<DebtModel?> settleDebt(String debtId, {String paymentMethod = 'EFT Wire', String? sourceEnvelopeId}) async {
    _ensureDefaultData();
    final idx = _mockDebts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return null;
    final debt = _mockDebts[idx];
    return recordDebtRepayment(
      debtId: debtId,
      amountZar: debt.currentOutstandingBalanceZar,
      paymentMethod: paymentMethod,
      sourceEnvelopeId: sourceEnvelopeId ?? debt.linkedEnvelopeId,
      notes: 'Full Payoff / Settle Up',
    );
  }

  /// Total active debt I owe (Liabilities)
  double getTotalDebtsOwedByMeZar() {
    _ensureDefaultData();
    return _mockDebts
        .where((d) => d.direction == DebtDirection.owedByMe && !d.isPaidOff)
        .fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);
  }

  /// Total debt owed to me (Receivables)
  double getTotalDebtsOwedToMeZar() {
    _ensureDefaultData();
    return _mockDebts
        .where((d) => d.direction == DebtDirection.owedToMe && !d.isPaidOff)
        .fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);
  }

  /// Consolidated Net Worth across Liquid Accounts, Physical/Intangible Assets, and Debts/Receivables
  double calculateConsolidatedNetWorthZar({double liquidAccountsTotalZar = 0.0}) {
    _ensureDefaultData();
    final assetsContribution = getTotalAssetsNetWorthContributionZar();
    final receivables = getTotalDebtsOwedToMeZar();
    final liabilities = getTotalDebtsOwedByMeZar();
    return liquidAccountsTotalZar + assetsContribution + receivables - liabilities;
  }
}
