enum VaultAccessLevel {
  readOnlySummary,
  fullDossier,
  emergencyTrustee,
}

class TrustedContact {
  final String id;
  final String fullName;
  final String relationship; // "Spouse / Partner", "Executor / Attorney", "Child / Heir", "Syndicate Co-Director"
  final String email;
  final String phoneNumber;
  final VaultAccessLevel accessLevel;
  final bool isConfirmed;
  final DateTime designatedAt;

  const TrustedContact({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.email,
    required this.phoneNumber,
    this.accessLevel = VaultAccessLevel.readOnlySummary,
    this.isConfirmed = true,
    required this.designatedAt,
  });

  String get accessLevelLabel {
    switch (accessLevel) {
      case VaultAccessLevel.readOnlySummary:
        return 'Read-Only Summary';
      case VaultAccessLevel.fullDossier:
        return 'Full Estate Dossier';
      case VaultAccessLevel.emergencyTrustee:
        return 'Emergency Trustee & Liquidator';
    }
  }

  TrustedContact copyWith({
    String? id,
    String? fullName,
    String? relationship,
    String? email,
    String? phoneNumber,
    VaultAccessLevel? accessLevel,
    bool? isConfirmed,
    DateTime? designatedAt,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accessLevel: accessLevel ?? this.accessLevel,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      designatedAt: designatedAt ?? this.designatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'relationship': relationship,
      'email': email,
      'phoneNumber': phoneNumber,
      'accessLevel': accessLevel.name,
      'isConfirmed': isConfirmed,
      'designatedAt': designatedAt.toIso8601String(),
    };
  }

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      relationship: json['relationship'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      accessLevel: VaultAccessLevel.values.firstWhere(
        (a) => a.name == json['accessLevel'],
        orElse: () => VaultAccessLevel.readOnlySummary,
      ),
      isConfirmed: json['isConfirmed'] as bool? ?? true,
      designatedAt: DateTime.parse(json['designatedAt'] as String),
    );
  }
}

class VaultAuditLog {
  final String id;
  final DateTime timestamp;
  final String action; // 'VAULT_OPENED', 'DOSSIER_VIEWED', 'ESTATE_EXPORTED', 'CONTACTS_UPDATED'
  final String actorName;
  final String details;

  const VaultAuditLog({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.actorName,
    required this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'actorName': actorName,
      'details': details,
    };
  }

  factory VaultAuditLog.fromJson(Map<String, dynamic> json) {
    return VaultAuditLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: json['action'] as String,
      actorName: json['actorName'] as String,
      details: json['details'] as String,
    );
  }
}

class LegacyVaultConfig {
  final bool isActivated;
  final bool requiresSecondaryPin;
  final List<String> includedAssetIds;
  final List<String> includedAccountIds;
  final String executorDirectives;
  final String emergencyTrusteeNotes;
  final DateTime? lastExportedAt;

  const LegacyVaultConfig({
    this.isActivated = false,
    this.requiresSecondaryPin = true,
    this.includedAssetIds = const [
      'ASSET_REAL_ESTATE_01',
      'ASSET_VEHICLE_01',
      'ASSET_IP_ALGO_01',
      'ASSET_CRYPTO_VAULT_01',
    ],
    this.includedAccountIds = const [
      'ACC_FNB_01',
      'ACC_STDBANK_01',
      'ACC_INVESTEC_01',
    ],
    this.executorDirectives = 'In the event of executor execution: contact Bowman Gilfillan Attorneys (Ref #EST-2026-ZA). All IP algorithms to remain under syndicate escrow trust. Tangible property liquidation proceeds to be settled directly to designated heirs per Last Will & Testament.',
    this.emergencyTrusteeNotes = 'Emergency recovery keys and deed title documents are housed in the physical fireproof vault at Standard Bank Sandton Safe Custody (Box #912).',
    this.lastExportedAt,
  });

  LegacyVaultConfig copyWith({
    bool? isActivated,
    bool? requiresSecondaryPin,
    List<String>? includedAssetIds,
    List<String>? includedAccountIds,
    String? executorDirectives,
    String? emergencyTrusteeNotes,
    DateTime? lastExportedAt,
  }) {
    return LegacyVaultConfig(
      isActivated: isActivated ?? this.isActivated,
      requiresSecondaryPin: requiresSecondaryPin ?? this.requiresSecondaryPin,
      includedAssetIds: includedAssetIds ?? this.includedAssetIds,
      includedAccountIds: includedAccountIds ?? this.includedAccountIds,
      executorDirectives: executorDirectives ?? this.executorDirectives,
      emergencyTrusteeNotes: emergencyTrusteeNotes ?? this.emergencyTrusteeNotes,
      lastExportedAt: lastExportedAt ?? this.lastExportedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActivated': isActivated,
      'requiresSecondaryPin': requiresSecondaryPin,
      'includedAssetIds': includedAssetIds,
      'includedAccountIds': includedAccountIds,
      'executorDirectives': executorDirectives,
      'emergencyTrusteeNotes': emergencyTrusteeNotes,
      'lastExportedAt': lastExportedAt?.toIso8601String(),
    };
  }

  factory LegacyVaultConfig.fromJson(Map<String, dynamic> json) {
    return LegacyVaultConfig(
      isActivated: json['isActivated'] as bool? ?? false,
      requiresSecondaryPin: json['requiresSecondaryPin'] as bool? ?? true,
      includedAssetIds: (json['includedAssetIds'] as List<dynamic>?)?.cast<String>() ??
          const [
            'ASSET_REAL_ESTATE_01',
            'ASSET_VEHICLE_01',
            'ASSET_IP_ALGO_01',
            'ASSET_CRYPTO_VAULT_01',
          ],
      includedAccountIds: (json['includedAccountIds'] as List<dynamic>?)?.cast<String>() ??
          const [
            'ACC_FNB_01',
            'ACC_STDBANK_01',
            'ACC_INVESTEC_01',
          ],
      executorDirectives: json['executorDirectives'] as String? ?? '',
      emergencyTrusteeNotes: json['emergencyTrusteeNotes'] as String? ?? '',
      lastExportedAt: json['lastExportedAt'] != null ? DateTime.parse(json['lastExportedAt'] as String) : null,
    );
  }
}
