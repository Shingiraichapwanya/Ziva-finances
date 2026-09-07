/// Direction of the debt
enum DebtDirection {
  owedByMe, // Liability: Money I owe to someone/institution
  owedToMe, // Receivable: Money owed to me
}

/// Category of debt / credit
enum DebtType {
  personalLoan,
  creditCard,
  assetFinance,
  mortgage,
  invoiceReceivable,
  other,
}

/// Status of the debt item
enum DebtStatus {
  current,
  overdue,
  paidOff,
}

/// Single transaction/repayment event on a debt record
class DebtRepaymentModel {
  final String id;
  final String debtId;
  final double amountZar;
  final DateTime paymentDate;
  final String paymentMethod; // EFT, Wire, Cash, Card, Crypto
  final String? sourceEnvelopeId;
  final String? sourceEnvelopeName;
  final String notes;
  final DateTime createdAt;

  const DebtRepaymentModel({
    required this.id,
    required this.debtId,
    required this.amountZar,
    required this.paymentDate,
    this.paymentMethod = 'EFT',
    this.sourceEnvelopeId,
    this.sourceEnvelopeName,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'debt_id': debtId,
        'amount_zar': amountZar,
        'payment_date': paymentDate.toIso8601String(),
        'payment_method': paymentMethod,
        'source_envelope_id': sourceEnvelopeId,
        'source_envelope_name': sourceEnvelopeName,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory DebtRepaymentModel.fromJson(Map<String, dynamic> json) => DebtRepaymentModel(
        id: json['id'] as String,
        debtId: json['debt_id'] as String,
        amountZar: (json['amount_zar'] as num?)?.toDouble() ?? 0.0,
        paymentDate: json['payment_date'] != null
            ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        paymentMethod: json['payment_method'] as String? ?? 'EFT',
        sourceEnvelopeId: json['source_envelope_id'] as String?,
        sourceEnvelopeName: json['source_envelope_name'] as String?,
        notes: json['notes'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Comprehensive model for Debt & Credit Ledger items
class DebtModel {
  final String id;
  final String counterparty;
  final DebtDirection direction;
  final DebtType debtType;
  final double originalPrincipalZar;
  final double currentOutstandingBalanceZar;
  final String currency;
  final double? interestRatePercent;
  final double? minimumMonthlyPaymentZar;
  final DateTime? dueDate;
  final String? linkedEnvelopeId;
  final String? linkedEnvelopeName;
  final DebtStatus status;
  final String notes;
  final List<DebtRepaymentModel> repayments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebtModel({
    required this.id,
    required this.counterparty,
    required this.direction,
    this.debtType = DebtType.personalLoan,
    required this.originalPrincipalZar,
    required this.currentOutstandingBalanceZar,
    this.currency = 'ZAR',
    this.interestRatePercent,
    this.minimumMonthlyPaymentZar,
    this.dueDate,
    this.linkedEnvelopeId,
    this.linkedEnvelopeName,
    this.status = DebtStatus.current,
    this.notes = '',
    this.repayments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Percentage of original principal settled
  double get pctSettled {
    if (originalPrincipalZar <= 0) return 100.0;
    final settled = originalPrincipalZar - currentOutstandingBalanceZar;
    return (settled / originalPrincipalZar * 100.0).clamp(0.0, 100.0);
  }

  /// Currency code alias for multi-currency uniformity
  String get currencyCode => currency;

  /// Whether debt is fully paid off
  bool get isPaidOff => currentOutstandingBalanceZar <= 0.01 || status == DebtStatus.paidOff;

  /// Whether debt is currently overdue
  bool get isOverdue {
    if (isPaidOff) return false;
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Total settled amount across all repayments
  double get totalRepaidZar {
    return repayments.fold(0.0, (sum, r) => sum + r.amountZar);
  }

  String get typeLabel {
    switch (debtType) {
      case DebtType.personalLoan:
        return 'Personal Loan';
      case DebtType.creditCard:
        return 'Credit Facility / Card';
      case DebtType.assetFinance:
        return 'Asset Finance';
      case DebtType.mortgage:
        return 'Mortgage Bond';
      case DebtType.invoiceReceivable:
        return 'Invoice Receivable';
      case DebtType.other:
        return 'Private Debt / Credit';
    }
  }

  String get directionLabel => direction == DebtDirection.owedByMe ? 'Debt I Owe (Liability)' : 'Owed to Me (Receivable)';

  DebtModel copyWith({
    String? counterparty,
    DebtDirection? direction,
    DebtType? debtType,
    double? originalPrincipalZar,
    double? currentOutstandingBalanceZar,
    String? currency,
    String? currencyCode,
    double? interestRatePercent,
    double? minimumMonthlyPaymentZar,
    DateTime? dueDate,
    String? linkedEnvelopeId,
    String? linkedEnvelopeName,
    DebtStatus? status,
    String? notes,
    List<DebtRepaymentModel>? repayments,
  }) {
    return DebtModel(
      id: id,
      counterparty: counterparty ?? this.counterparty,
      direction: direction ?? this.direction,
      debtType: debtType ?? this.debtType,
      originalPrincipalZar: originalPrincipalZar ?? this.originalPrincipalZar,
      currentOutstandingBalanceZar:
          currentOutstandingBalanceZar ?? this.currentOutstandingBalanceZar,
      currency: currencyCode ?? currency ?? this.currency,
      interestRatePercent: interestRatePercent ?? this.interestRatePercent,
      minimumMonthlyPaymentZar:
          minimumMonthlyPaymentZar ?? this.minimumMonthlyPaymentZar,
      dueDate: dueDate ?? this.dueDate,
      linkedEnvelopeId: linkedEnvelopeId ?? this.linkedEnvelopeId,
      linkedEnvelopeName: linkedEnvelopeName ?? this.linkedEnvelopeName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      repayments: repayments ?? this.repayments,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'counterparty': counterparty,
        'person_name': counterparty,
        'personName': counterparty,
        'direction': direction == DebtDirection.owedToMe ? 'owed_to_me' : 'owed_by_me',
        'debt_type': debtType.name,
        'amount': originalPrincipalZar,
        'original_principal_zar': originalPrincipalZar,
        'current_outstanding_balance_zar': currentOutstandingBalanceZar,
        'currency': currency,
        'currency_code': currency,
        'interest_rate_percent': interestRatePercent,
        'minimum_monthly_payment_zar': minimumMonthlyPaymentZar,
        'date': (dueDate ?? createdAt).toIso8601String().split('T')[0],
        'due_date': dueDate?.toIso8601String(),
        'linked_envelope_id': linkedEnvelopeId,
        'linked_envelope_name': linkedEnvelopeName,
        'status': status == DebtStatus.paidOff ? 'Settled' : 'Pending',
        'notes': notes,
        'repayments': repayments.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    final String cparty = (json['person_name'] ?? json['personName'] ?? json['counterparty'] ?? 'Counterparty').toString();
    
    // Direction mapping: 'owed_to_me' / 'owedToMe' -> DebtDirection.owedToMe
    final rawDir = (json['direction'] ?? '').toString().trim().toLowerCase();
    final DebtDirection dir = (rawDir == 'owed_to_me' || rawDir == 'owedtome')
        ? DebtDirection.owedToMe
        : DebtDirection.owedByMe;

    final num? rawAmount = (json['amount'] ?? json['original_principal_zar']) as num?;
    final double amountVal = (rawAmount ?? 0.0).toDouble();

    final num? rawOutstanding = (json['current_outstanding_balance_zar'] ?? json['amount']) as num?;
    final double outstandingVal = (rawOutstanding ?? amountVal).toDouble();

    final rawStatus = (json['status'] ?? '').toString();
    final DebtStatus stat = (rawStatus.toLowerCase() == 'settled' || rawStatus == 'paidoff')
        ? DebtStatus.paidOff
        : DebtStatus.current;

    final rawCurrency = (json['currency_code'] ?? json['currency'] ?? 'USD').toString().trim().toUpperCase();
    final effectiveCurrency = rawCurrency == 'ZIG' ? 'ZWG' : rawCurrency;

    return DebtModel(
      id: (json['id'] ?? '').toString(),
      counterparty: cparty,
      direction: dir,
      debtType: DebtType.values.firstWhere(
        (e) => e.name == json['debt_type'],
        orElse: () => DebtType.personalLoan,
      ),
      originalPrincipalZar: amountVal,
      currentOutstandingBalanceZar: (stat == DebtStatus.paidOff) ? 0.0 : outstandingVal,
      currency: effectiveCurrency,
      interestRatePercent: (json['interest_rate_percent'] as num?)?.toDouble(),
      minimumMonthlyPaymentZar: (json['minimum_monthly_payment_zar'] as num?)?.toDouble(),
      dueDate: json['due_date'] != null || json['date'] != null
          ? DateTime.tryParse((json['due_date'] ?? json['date']).toString())
          : null,
      linkedEnvelopeId: json['linked_envelope_id'] as String?,
      linkedEnvelopeName: json['linked_envelope_name'] as String?,
      status: stat,
      notes: (json['notes'] ?? '').toString(),
      repayments: (json['repayments'] as List<dynamic>?)
              ?.map((item) => DebtRepaymentModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
