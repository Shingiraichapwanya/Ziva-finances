enum StatementSource {
  bankApiSync,
  emailAttachment,
  statementUploadCsv,
  statementUploadPdf,
}

enum MatchedItemType {
  depositSlip,
  emailProposal,
  internalLedger,
  none,
}

enum ReconciliationMatchStatus {
  reconciled,
  needsReview,
  unmatchedException,
  stalePending,
}

class StatementTransaction {
  final String id;
  final String accountId;
  final String accountName;
  final DateTime statementDate;
  final double amountZar;
  final bool isCredit;
  final String reference;
  final String counterparty;
  final StatementSource source;
  final bool isReconciled;
  final String? matchedInternalId;

  const StatementTransaction({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.statementDate,
    required this.amountZar,
    required this.isCredit,
    required this.reference,
    required this.counterparty,
    this.source = StatementSource.bankApiSync,
    this.isReconciled = false,
    this.matchedInternalId,
  });

  StatementTransaction copyWith({
    String? id,
    String? accountId,
    String? accountName,
    DateTime? statementDate,
    double? amountZar,
    bool? isCredit,
    String? reference,
    String? counterparty,
    StatementSource? source,
    bool? isReconciled,
    String? matchedInternalId,
  }) {
    return StatementTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      statementDate: statementDate ?? this.statementDate,
      amountZar: amountZar ?? this.amountZar,
      isCredit: isCredit ?? this.isCredit,
      reference: reference ?? this.reference,
      counterparty: counterparty ?? this.counterparty,
      source: source ?? this.source,
      isReconciled: isReconciled ?? this.isReconciled,
      matchedInternalId: matchedInternalId ?? this.matchedInternalId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'accountName': accountName,
      'statementDate': statementDate.toIso8601String(),
      'amountZar': amountZar,
      'isCredit': isCredit,
      'reference': reference,
      'counterparty': counterparty,
      'source': source.name,
      'isReconciled': isReconciled,
      'matchedInternalId': matchedInternalId,
    };
  }

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    return StatementTransaction(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String,
      statementDate: DateTime.parse(json['statementDate'] as String),
      amountZar: (json['amountZar'] as num).toDouble(),
      isCredit: json['isCredit'] as bool? ?? false,
      reference: json['reference'] as String,
      counterparty: json['counterparty'] as String,
      source: StatementSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => StatementSource.bankApiSync,
      ),
      isReconciled: json['isReconciled'] as bool? ?? false,
      matchedInternalId: json['matchedInternalId'] as String?,
    );
  }
}

class ReconciliationMatch {
  final String id;
  final StatementTransaction statementTransaction;
  final MatchedItemType matchedItemType;
  final String? matchedItemId;
  final String? matchedDescription;
  final double matchScore; // 0.0 to 1.0
  final ReconciliationMatchStatus status;
  final String reconciliationNotes;
  final List<String> candidateMatchIds;
  final DateTime? resolvedAt;

  const ReconciliationMatch({
    required this.id,
    required this.statementTransaction,
    this.matchedItemType = MatchedItemType.none,
    this.matchedItemId,
    this.matchedDescription,
    this.matchScore = 0.0,
    required this.status,
    this.reconciliationNotes = '',
    this.candidateMatchIds = const [],
    this.resolvedAt,
  });

  bool get isCleanMatch => status == ReconciliationMatchStatus.reconciled;
  bool get hasException => status == ReconciliationMatchStatus.needsReview || status == ReconciliationMatchStatus.unmatchedException;

  ReconciliationMatch copyWith({
    String? id,
    StatementTransaction? statementTransaction,
    MatchedItemType? matchedItemType,
    String? matchedItemId,
    String? matchedDescription,
    double? matchScore,
    ReconciliationMatchStatus? status,
    String? reconciliationNotes,
    List<String>? candidateMatchIds,
    DateTime? resolvedAt,
  }) {
    return ReconciliationMatch(
      id: id ?? this.id,
      statementTransaction: statementTransaction ?? this.statementTransaction,
      matchedItemType: matchedItemType ?? this.matchedItemType,
      matchedItemId: matchedItemId ?? this.matchedItemId,
      matchedDescription: matchedDescription ?? this.matchedDescription,
      matchScore: matchScore ?? this.matchScore,
      status: status ?? this.status,
      reconciliationNotes: reconciliationNotes ?? this.reconciliationNotes,
      candidateMatchIds: candidateMatchIds ?? this.candidateMatchIds,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class ReconciliationSummary {
  final int reconciledCount;
  final double reconciledTotalZar;
  final int unreconciledCount;
  final double unreconciledTotalZar;
  final int exceptionsCount;
  final Map<String, int> accountBreakdowns;

  const ReconciliationSummary({
    required this.reconciledCount,
    required this.reconciledTotalZar,
    required this.unreconciledCount,
    required this.unreconciledTotalZar,
    required this.exceptionsCount,
    this.accountBreakdowns = const {},
  });

  double get reconciliationRatePercent {
    final total = reconciledCount + unreconciledCount;
    if (total == 0) return 100.0;
    return (reconciledCount / total) * 100.0;
  }
}
