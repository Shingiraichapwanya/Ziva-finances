enum EmailDocumentType {
  bankStatement,
  cardStatement,
  paymentNotification,
  invoice,
  receipt,
  transferAdvice,
}

enum ProposalStatus {
  pending,
  autoAdded,
  kept,
  removed,
  ignoredPattern,
}

class EmailTransactionProposal {
  final String id;
  final String emailSubject;
  final String senderEmail;
  final DateTime receivedDate;
  final EmailDocumentType documentType;
  final double extractedAmount;
  final String currency;
  final String counterparty;
  final String referenceNumber;
  final String accountIdentifier; // e.g. "FNB *4921", "Standard Bank Premier"
  final String suggestedEnvelopeId;
  final String suggestedAccountId;
  final bool isCredit;
  final double confidenceScore; // 0.0 to 1.0
  final Map<String, double> confidenceFactors;
  final ProposalStatus status;
  final String rawSnippet;
  final DateTime? reviewedAt;
  final String? createdTransactionId;

  const EmailTransactionProposal({
    required this.id,
    required this.emailSubject,
    required this.senderEmail,
    required this.receivedDate,
    required this.documentType,
    required this.extractedAmount,
    this.currency = 'ZAR',
    required this.counterparty,
    required this.referenceNumber,
    required this.accountIdentifier,
    this.suggestedEnvelopeId = 'ENV_ESSENTIALS_01',
    this.suggestedAccountId = 'ACC_FNB_01',
    this.isCredit = false,
    required this.confidenceScore,
    this.confidenceFactors = const {},
    this.status = ProposalStatus.pending,
    required this.rawSnippet,
    this.reviewedAt,
    this.createdTransactionId,
  });

  bool get isHighConfidence => confidenceScore >= 0.95;
  bool get isMediumConfidence => confidenceScore >= 0.70 && confidenceScore < 0.95;
  bool get isLowConfidence => confidenceScore < 0.70;

  String get formattedConfidence => '${(confidenceScore * 100).toStringAsFixed(0)}%';

  EmailTransactionProposal copyWith({
    String? id,
    String? emailSubject,
    String? senderEmail,
    DateTime? receivedDate,
    EmailDocumentType? documentType,
    double? extractedAmount,
    String? currency,
    String? counterparty,
    String? referenceNumber,
    String? accountIdentifier,
    String? suggestedEnvelopeId,
    String? suggestedAccountId,
    bool? isCredit,
    double? confidenceScore,
    Map<String, double>? confidenceFactors,
    ProposalStatus? status,
    String? rawSnippet,
    DateTime? reviewedAt,
    String? createdTransactionId,
  }) {
    return EmailTransactionProposal(
      id: id ?? this.id,
      emailSubject: emailSubject ?? this.emailSubject,
      senderEmail: senderEmail ?? this.senderEmail,
      receivedDate: receivedDate ?? this.receivedDate,
      documentType: documentType ?? this.documentType,
      extractedAmount: extractedAmount ?? this.extractedAmount,
      currency: currency ?? this.currency,
      counterparty: counterparty ?? this.counterparty,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      suggestedEnvelopeId: suggestedEnvelopeId ?? this.suggestedEnvelopeId,
      suggestedAccountId: suggestedAccountId ?? this.suggestedAccountId,
      isCredit: isCredit ?? this.isCredit,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceFactors: confidenceFactors ?? this.confidenceFactors,
      status: status ?? this.status,
      rawSnippet: rawSnippet ?? this.rawSnippet,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdTransactionId: createdTransactionId ?? this.createdTransactionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emailSubject': emailSubject,
      'senderEmail': senderEmail,
      'receivedDate': receivedDate.toIso8601String(),
      'documentType': documentType.name,
      'extractedAmount': extractedAmount,
      'currency': currency,
      'counterparty': counterparty,
      'referenceNumber': referenceNumber,
      'accountIdentifier': accountIdentifier,
      'suggestedEnvelopeId': suggestedEnvelopeId,
      'suggestedAccountId': suggestedAccountId,
      'isCredit': isCredit,
      'confidenceScore': confidenceScore,
      'confidenceFactors': confidenceFactors,
      'status': status.name,
      'rawSnippet': rawSnippet,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'createdTransactionId': createdTransactionId,
    };
  }

  factory EmailTransactionProposal.fromJson(Map<String, dynamic> json) {
    return EmailTransactionProposal(
      id: json['id'] as String,
      emailSubject: json['emailSubject'] as String,
      senderEmail: json['senderEmail'] as String,
      receivedDate: DateTime.parse(json['receivedDate'] as String),
      documentType: EmailDocumentType.values.firstWhere(
        (e) => e.name == json['documentType'],
        orElse: () => EmailDocumentType.receipt,
      ),
      extractedAmount: (json['extractedAmount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'ZAR',
      counterparty: json['counterparty'] as String,
      referenceNumber: json['referenceNumber'] as String,
      accountIdentifier: json['accountIdentifier'] as String,
      suggestedEnvelopeId: json['suggestedEnvelopeId'] as String? ?? 'ENV_ESSENTIALS_01',
      suggestedAccountId: json['suggestedAccountId'] as String? ?? 'ACC_FNB_01',
      isCredit: json['isCredit'] as bool? ?? false,
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      confidenceFactors: (json['confidenceFactors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      status: ProposalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProposalStatus.pending,
      ),
      rawSnippet: json['rawSnippet'] as String,
      reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt'] as String) : null,
      createdTransactionId: json['createdTransactionId'] as String?,
    );
  }
}

class GoogleWorkspaceConnection {
  final bool isConnected;
  final String accountEmail;
  final DateTime? lastScanTime;
  final int scanIntervalMinutes;
  final List<String> ignoredSenders;
  final List<String> ignoredPatterns;

  const GoogleWorkspaceConnection({
    this.isConnected = true,
    this.accountEmail = 'shingiraichapwanya@gmail.com',
    this.lastScanTime,
    this.scanIntervalMinutes = 15,
    this.ignoredSenders = const ['promotions@marketing.com', 'newsletter@invest.com'],
    this.ignoredPatterns = const ['Order #CANCELLED', 'Test Inflow'],
  });

  GoogleWorkspaceConnection copyWith({
    bool? isConnected,
    String? accountEmail,
    DateTime? lastScanTime,
    int? scanIntervalMinutes,
    List<String>? ignoredSenders,
    List<String>? ignoredPatterns,
  }) {
    return GoogleWorkspaceConnection(
      isConnected: isConnected ?? this.isConnected,
      accountEmail: accountEmail ?? this.accountEmail,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      scanIntervalMinutes: scanIntervalMinutes ?? this.scanIntervalMinutes,
      ignoredSenders: ignoredSenders ?? this.ignoredSenders,
      ignoredPatterns: ignoredPatterns ?? this.ignoredPatterns,
    );
  }
}
