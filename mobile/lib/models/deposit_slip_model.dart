enum DepositSlipStatus {
  pendingOcr,
  readyForReview,
  approvedPendingDeposit,
  reconciled,
  rejected,
}

enum AccountMatchType {
  exact,
  partial,
  manual,
  unmatched,
}

class DepositSlipModel {
  final String id;
  final String bankName; // e.g. "Standard Bank", "FBC Bank", "Ecobank", "FNB"
  final String? imagePath;
  final String? imageDataUri;
  final DateTime uploadedAt;

  // Extracted OCR fields with per-field confidence scores (0.0 to 1.0)
  final double? extractedAmount;
  final double amountConfidence;

  final DateTime? extractedDate;
  final double dateConfidence;

  final String? extractedAccountNumber;
  final double accountConfidence;

  final String? extractedBranch;
  final double branchConfidence;

  final String? extractedReference;

  // Internal account mapping
  final String? matchedAccountId;
  final String? matchedAccountName;
  final AccountMatchType matchType;

  // User inline corrections (if user modifies prefilled fields before approval)
  final double? userCorrectedAmount;
  final DateTime? userCorrectedDate;
  final String? userCorrectedAccountId;

  final DepositSlipStatus status;
  final String? reconciledTransactionId;
  final String? notes;

  const DepositSlipModel({
    required this.id,
    this.bankName = 'Standard Bank',
    this.imagePath,
    this.imageDataUri,
    required this.uploadedAt,
    this.extractedAmount,
    this.amountConfidence = 0.92,
    this.extractedDate,
    this.dateConfidence = 0.88,
    this.extractedAccountNumber,
    this.accountConfidence = 0.85,
    this.extractedBranch,
    this.branchConfidence = 0.80,
    this.extractedReference,
    this.matchedAccountId,
    this.matchedAccountName,
    this.matchType = AccountMatchType.exact,
    this.userCorrectedAmount,
    this.userCorrectedDate,
    this.userCorrectedAccountId,
    this.status = DepositSlipStatus.readyForReview,
    this.reconciledTransactionId,
    this.notes,
  });

  double get effectiveAmount => userCorrectedAmount ?? extractedAmount ?? 0.0;
  DateTime get effectiveDate => userCorrectedDate ?? extractedDate ?? uploadedAt;
  String? get effectiveAccountId => userCorrectedAccountId ?? matchedAccountId;

  double get overallConfidence {
    final scores = [amountConfidence, dateConfidence, accountConfidence, branchConfidence];
    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  String get formattedOverallConfidence => '${(overallConfidence * 100).toStringAsFixed(0)}%';
  String get formattedAmount => 'R ${effectiveAmount.toStringAsFixed(2)}';

  bool get isApproved => status == DepositSlipStatus.approvedPendingDeposit || status == DepositSlipStatus.reconciled;

  DepositSlipModel copyWith({
    String? id,
    String? bankName,
    String? imagePath,
    String? imageDataUri,
    DateTime? uploadedAt,
    double? extractedAmount,
    double? amountConfidence,
    DateTime? extractedDate,
    double? dateConfidence,
    String? extractedAccountNumber,
    double? accountConfidence,
    String? extractedBranch,
    double? branchConfidence,
    String? extractedReference,
    String? matchedAccountId,
    String? matchedAccountName,
    AccountMatchType? matchType,
    double? userCorrectedAmount,
    DateTime? userCorrectedDate,
    String? userCorrectedAccountId,
    DepositSlipStatus? status,
    String? reconciledTransactionId,
    String? notes,
  }) {
    return DepositSlipModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      imagePath: imagePath ?? this.imagePath,
      imageDataUri: imageDataUri ?? this.imageDataUri,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      extractedAmount: extractedAmount ?? this.extractedAmount,
      amountConfidence: amountConfidence ?? this.amountConfidence,
      extractedDate: extractedDate ?? this.extractedDate,
      dateConfidence: dateConfidence ?? this.dateConfidence,
      extractedAccountNumber: extractedAccountNumber ?? this.extractedAccountNumber,
      accountConfidence: accountConfidence ?? this.accountConfidence,
      extractedBranch: extractedBranch ?? this.extractedBranch,
      branchConfidence: branchConfidence ?? this.branchConfidence,
      extractedReference: extractedReference ?? this.extractedReference,
      matchedAccountId: matchedAccountId ?? this.matchedAccountId,
      matchedAccountName: matchedAccountName ?? this.matchedAccountName,
      matchType: matchType ?? this.matchType,
      userCorrectedAmount: userCorrectedAmount ?? this.userCorrectedAmount,
      userCorrectedDate: userCorrectedDate ?? this.userCorrectedDate,
      userCorrectedAccountId: userCorrectedAccountId ?? this.userCorrectedAccountId,
      status: status ?? this.status,
      reconciledTransactionId: reconciledTransactionId ?? this.reconciledTransactionId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankName': bankName,
      'imagePath': imagePath,
      'imageDataUri': imageDataUri,
      'uploadedAt': uploadedAt.toIso8601String(),
      'extractedAmount': extractedAmount,
      'amountConfidence': amountConfidence,
      'extractedDate': extractedDate?.toIso8601String(),
      'dateConfidence': dateConfidence,
      'extractedAccountNumber': extractedAccountNumber,
      'accountConfidence': accountConfidence,
      'extractedBranch': extractedBranch,
      'branchConfidence': branchConfidence,
      'extractedReference': extractedReference,
      'matchedAccountId': matchedAccountId,
      'matchedAccountName': matchedAccountName,
      'matchType': matchType.name,
      'userCorrectedAmount': userCorrectedAmount,
      'userCorrectedDate': userCorrectedDate?.toIso8601String(),
      'userCorrectedAccountId': userCorrectedAccountId,
      'status': status.name,
      'reconciledTransactionId': reconciledTransactionId,
      'notes': notes,
    };
  }

  factory DepositSlipModel.fromJson(Map<String, dynamic> json) {
    return DepositSlipModel(
      id: json['id'] as String,
      bankName: json['bankName'] as String? ?? 'Standard Bank',
      imagePath: json['imagePath'] as String?,
      imageDataUri: json['imageDataUri'] as String?,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      extractedAmount: (json['extractedAmount'] as num?)?.toDouble(),
      amountConfidence: (json['amountConfidence'] as num?)?.toDouble() ?? 0.85,
      extractedDate: json['extractedDate'] != null ? DateTime.parse(json['extractedDate'] as String) : null,
      dateConfidence: (json['dateConfidence'] as num?)?.toDouble() ?? 0.85,
      extractedAccountNumber: json['extractedAccountNumber'] as String?,
      accountConfidence: (json['accountConfidence'] as num?)?.toDouble() ?? 0.85,
      extractedBranch: json['extractedBranch'] as String?,
      branchConfidence: (json['branchConfidence'] as num?)?.toDouble() ?? 0.80,
      extractedReference: json['extractedReference'] as String?,
      matchedAccountId: json['matchedAccountId'] as String?,
      matchedAccountName: json['matchedAccountName'] as String?,
      matchType: AccountMatchType.values.firstWhere(
        (m) => m.name == json['matchType'],
        orElse: () => AccountMatchType.exact,
      ),
      userCorrectedAmount: (json['userCorrectedAmount'] as num?)?.toDouble(),
      userCorrectedDate: json['userCorrectedDate'] != null ? DateTime.parse(json['userCorrectedDate'] as String) : null,
      userCorrectedAccountId: json['userCorrectedAccountId'] as String?,
      status: DepositSlipStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DepositSlipStatus.readyForReview,
      ),
      reconciledTransactionId: json['reconciledTransactionId'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
