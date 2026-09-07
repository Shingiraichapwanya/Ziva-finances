class AccountModel {
  final String accountId;
  final String accountName;
  final String financialInstitution;
  final String countryCode;
  final String primaryCurrency;
  final String cashFlowTier; // 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', 'LONG_TERM_VAULT'
  final String accountType;
  final bool isVaultLocked;
  final int withdrawalNoticeDays;
  final String accountNumberMasked;
  final double nativeBalance;
  final bool isActive;

  AccountModel({
    required this.accountId,
    required this.accountName,
    required this.financialInstitution,
    required this.countryCode,
    required this.primaryCurrency,
    required this.cashFlowTier,
    required this.accountType,
    this.isVaultLocked = false,
    this.withdrawalNoticeDays = 0,
    this.accountNumberMasked = '****',
    required this.nativeBalance,
    this.isActive = true,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    final rawBalance = json['nativeBalance'] ?? json['native_balance'] ?? 0.0;
    final double balance = rawBalance is num
        ? rawBalance.toDouble()
        : double.tryParse(rawBalance.toString()) ?? 0.0;

    final rawNoticeDays = json['withdrawalNoticeDays'] ?? json['withdrawal_notice_days'] ?? 0;
    final int noticeDays = rawNoticeDays is int
        ? rawNoticeDays
        : int.tryParse(rawNoticeDays.toString()) ?? 0;

    return AccountModel(
      accountId: (json['accountId'] ?? json['account_id'] ?? '').toString(),
      accountName: (json['accountName'] ?? json['account_name'] ?? '').toString(),
      financialInstitution: (json['financialInstitution'] ?? json['financial_institution'] ?? '').toString(),
      countryCode: (json['countryCode'] ?? json['country_code'] ?? 'ZA').toString(),
      primaryCurrency: (json['primaryCurrency'] ?? json['primary_currency'] ?? 'ZAR').toString(),
      cashFlowTier: (json['cashFlowTier'] ?? json['cash_flow_tier'] ?? 'DAILY_SPENDING').toString(),
      accountType: (json['accountType'] ?? json['account_type'] ?? 'CHECKING').toString(),
      isVaultLocked: json['isVaultLocked'] == true || json['is_vault_locked'] == 1,
      withdrawalNoticeDays: noticeDays,
      accountNumberMasked: (json['accountNumberMasked'] ?? json['account_number_masked'] ?? '****').toString(),
      nativeBalance: balance,
      isActive: json['isActive'] == null ? true : (json['isActive'] == true || json['is_active'] == 1),
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'account_id': accountId,
      'account_name': accountName,
      'financial_institution': financialInstitution,
      'country_code': countryCode,
      'primary_currency': primaryCurrency,
      'cash_flow_tier': cashFlowTier,
      'account_type': accountType,
      'is_vault_locked': isVaultLocked ? 1 : 0,
      'withdrawal_notice_days': withdrawalNoticeDays,
      'account_number_masked': accountNumberMasked,
      'native_balance': nativeBalance,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() => toSqliteMap();

  AccountModel copyWith({
    String? accountId,
    String? accountName,
    String? financialInstitution,
    String? countryCode,
    String? primaryCurrency,
    String? cashFlowTier,
    String? accountType,
    bool? isVaultLocked,
    int? withdrawalNoticeDays,
    String? accountNumberMasked,
    double? nativeBalance,
    bool? isActive,
  }) {
    return AccountModel(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      financialInstitution: financialInstitution ?? this.financialInstitution,
      countryCode: countryCode ?? this.countryCode,
      primaryCurrency: primaryCurrency ?? this.primaryCurrency,
      cashFlowTier: cashFlowTier ?? this.cashFlowTier,
      accountType: accountType ?? this.accountType,
      isVaultLocked: isVaultLocked ?? this.isVaultLocked,
      withdrawalNoticeDays: withdrawalNoticeDays ?? this.withdrawalNoticeDays,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      nativeBalance: nativeBalance ?? this.nativeBalance,
      isActive: isActive ?? this.isActive,
    );
  }
}
