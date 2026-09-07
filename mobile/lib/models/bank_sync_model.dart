enum BankSyncStatus {
  synced,
  syncing,
  failed,
  pendingAuth,
}

class BankSyncConnection {
  final String id;
  final String institutionName; // e.g. "Standard Bank", "First National Bank", "Nedbank", "Investec", "Ecobank"
  final String accountNumberMasked; // e.g. "•••• 4921"
  final String accountType; // "Private Cheque", "Money Market Vault", "Offshore USD"
  final double currentBalanceZar;
  final String nativeCurrency;
  final double nativeBalance;
  final DateTime lastSyncedAt;
  final BankSyncStatus status;
  final String provider; // "OpenBanking ZA", "Stitch Direct", "Plaid"
  final String linkedLocalAccountId;
  final String? errorMessage;

  const BankSyncConnection({
    required this.id,
    required this.institutionName,
    required this.accountNumberMasked,
    required this.accountType,
    required this.currentBalanceZar,
    this.nativeCurrency = 'ZAR',
    required this.nativeBalance,
    required this.lastSyncedAt,
    this.status = BankSyncStatus.synced,
    this.provider = 'OpenBanking ZA',
    required this.linkedLocalAccountId,
    this.errorMessage,
  });

  String get syncAgeDescription {
    final diff = DateTime.now().difference(lastSyncedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  BankSyncConnection copyWith({
    String? id,
    String? institutionName,
    String? accountNumberMasked,
    String? accountType,
    double? currentBalanceZar,
    String? nativeCurrency,
    double? nativeBalance,
    DateTime? lastSyncedAt,
    BankSyncStatus? status,
    String? provider,
    String? linkedLocalAccountId,
    String? errorMessage,
  }) {
    return BankSyncConnection(
      id: id ?? this.id,
      institutionName: institutionName ?? this.institutionName,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      accountType: accountType ?? this.accountType,
      currentBalanceZar: currentBalanceZar ?? this.currentBalanceZar,
      nativeCurrency: nativeCurrency ?? this.nativeCurrency,
      nativeBalance: nativeBalance ?? this.nativeBalance,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      linkedLocalAccountId: linkedLocalAccountId ?? this.linkedLocalAccountId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institutionName': institutionName,
      'accountNumberMasked': accountNumberMasked,
      'accountType': accountType,
      'currentBalanceZar': currentBalanceZar,
      'nativeCurrency': nativeCurrency,
      'nativeBalance': nativeBalance,
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
      'status': status.name,
      'provider': provider,
      'linkedLocalAccountId': linkedLocalAccountId,
      'errorMessage': errorMessage,
    };
  }

  factory BankSyncConnection.fromJson(Map<String, dynamic> json) {
    return BankSyncConnection(
      id: json['id'] as String,
      institutionName: json['institutionName'] as String,
      accountNumberMasked: json['accountNumberMasked'] as String,
      accountType: json['accountType'] as String,
      currentBalanceZar: (json['currentBalanceZar'] as num).toDouble(),
      nativeCurrency: json['nativeCurrency'] as String? ?? 'ZAR',
      nativeBalance: (json['nativeBalance'] as num).toDouble(),
      lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String),
      status: BankSyncStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BankSyncStatus.synced,
      ),
      provider: json['provider'] as String? ?? 'OpenBanking ZA',
      linkedLocalAccountId: json['linkedLocalAccountId'] as String,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
