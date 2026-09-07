import 'dart:math' as math;

/// Types of assets supported in Ziva Finance
enum AssetType {
  tangible,
  intangible,
}

/// Categories of assets
enum AssetCategory {
  realEstate,
  vehicle,
  equipment,
  cashEquivalent,
  investment,
  ipPatent,
  brandDomain,
  digitalAsset,
  other,
}

/// Depreciation methods supported
enum DepreciationMethod {
  none,
  straightLine,
  reducingBalance,
  amortization,
}

/// Ownership structure
enum OwnershipType {
  solo,
  joint,
}

/// Comprehensive model for Tangible and Intangible Assets
class AssetModel {
  final String id;
  final String name;
  final AssetType type;
  final AssetCategory category;
  final double currentValueZar;
  final double acquisitionCostZar;
  final DateTime acquisitionDate;
  final DepreciationMethod depreciationMethod;
  final double usefulLifeYears;
  final double depreciationRatePercent;
  final String location;
  final String registrationNumber;
  final String documentationReference;
  final OwnershipType ownershipType;
  final double myOwnershipPercentage;
  final double partnerOwnershipPercentage;
  final String? linkedLiabilityId;
  final String? linkedLiabilityName;
  final double linkedLiabilityAmountZar;
  final String notes;
  final bool includeInNetWorth;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssetModel({
    required this.id,
    required this.name,
    this.type = AssetType.tangible,
    this.category = AssetCategory.other,
    required this.currentValueZar,
    required this.acquisitionCostZar,
    required this.acquisitionDate,
    this.depreciationMethod = DepreciationMethod.none,
    this.usefulLifeYears = 5.0,
    this.depreciationRatePercent = 0.0,
    this.location = '',
    this.registrationNumber = '',
    this.documentationReference = '',
    this.ownershipType = OwnershipType.solo,
    this.myOwnershipPercentage = 100.0,
    this.partnerOwnershipPercentage = 0.0,
    this.linkedLiabilityId,
    this.linkedLiabilityName,
    this.linkedLiabilityAmountZar = 0.0,
    this.notes = '',
    this.includeInNetWorth = true,
    this.currencyCode = 'ZAR',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Years held since acquisition
  double get yearsHeld {
    final diffDays = DateTime.now().difference(acquisitionDate).inDays;
    return (diffDays / 365.25).clamp(0.0, 100.0);
  }

  /// Automatically calculated accumulated depreciation
  double get accumulatedDepreciationZar {
    if (depreciationMethod == DepreciationMethod.none) return 0.0;

    if (depreciationMethod == DepreciationMethod.straightLine ||
        depreciationMethod == DepreciationMethod.amortization) {
      if (usefulLifeYears <= 0) return 0.0;
      final annualDepreciation = acquisitionCostZar / usefulLifeYears;
      final total = annualDepreciation * yearsHeld;
      return total.clamp(0.0, acquisitionCostZar);
    }

    if (depreciationMethod == DepreciationMethod.reducingBalance) {
      final rate = (depreciationRatePercent > 0
              ? depreciationRatePercent
              : (usefulLifeYears > 0 ? (100.0 / usefulLifeYears) : 20.0)) /
          100.0;
      final remainingValue = acquisitionCostZar * math.pow(1.0 - rate.clamp(0.0, 0.9), yearsHeld);
      final total = acquisitionCostZar - remainingValue;
      return total.clamp(0.0, acquisitionCostZar);
    }

    return 0.0;
  }

  /// Net Book Value (Cost - Accumulated Depreciation)
  double get netBookValueZar {
    if (depreciationMethod == DepreciationMethod.none) {
      return currentValueZar;
    }
    final nbv = acquisitionCostZar - accumulatedDepreciationZar;
    return nbv.clamp(0.0, double.infinity);
  }

  /// Effective equity contribution to Net Worth (respecting ownership % and linked liabilities)
  double get effectiveNetWorthContributionZar {
    if (!includeInNetWorth) return 0.0;
    final ownershipShare = (myOwnershipPercentage / 100.0).clamp(0.0, 1.0);
    final grossShare = currentValueZar * ownershipShare;
    final netShare = grossShare - (linkedLiabilityAmountZar * ownershipShare);
    return math.max(0.0, netShare);
  }

  String get categoryLabel {
    switch (category) {
      case AssetCategory.realEstate:
        return 'Real Estate';
      case AssetCategory.vehicle:
        return 'Vehicle';
      case AssetCategory.equipment:
        return 'Equipment & Hardware';
      case AssetCategory.cashEquivalent:
        return 'Cash & Reserves';
      case AssetCategory.investment:
        return 'Equities & Vaults';
      case AssetCategory.ipPatent:
        return 'Intellectual Property & Patents';
      case AssetCategory.brandDomain:
        return 'Brand, Domains & Goodwill';
      case AssetCategory.digitalAsset:
        return 'Digital Asset & Crypto';
      case AssetCategory.other:
        return 'Alternative Asset';
    }
  }

  String get typeLabel => type == AssetType.tangible ? 'Tangible Asset' : 'Intangible Asset';

  AssetModel copyWith({
    String? name,
    AssetType? type,
    AssetCategory? category,
    double? currentValueZar,
    double? acquisitionCostZar,
    DateTime? acquisitionDate,
    DepreciationMethod? depreciationMethod,
    double? usefulLifeYears,
    double? depreciationRatePercent,
    String? location,
    String? registrationNumber,
    String? documentationReference,
    OwnershipType? ownershipType,
    double? myOwnershipPercentage,
    double? partnerOwnershipPercentage,
    String? linkedLiabilityId,
    String? linkedLiabilityName,
    double? linkedLiabilityAmountZar,
    String? notes,
    bool? includeInNetWorth,
    String? currencyCode,
  }) {
    return AssetModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      currentValueZar: currentValueZar ?? this.currentValueZar,
      acquisitionCostZar: acquisitionCostZar ?? this.acquisitionCostZar,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      depreciationMethod: depreciationMethod ?? this.depreciationMethod,
      usefulLifeYears: usefulLifeYears ?? this.usefulLifeYears,
      depreciationRatePercent: depreciationRatePercent ?? this.depreciationRatePercent,
      location: location ?? this.location,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      documentationReference: documentationReference ?? this.documentationReference,
      ownershipType: ownershipType ?? this.ownershipType,
      myOwnershipPercentage: myOwnershipPercentage ?? this.myOwnershipPercentage,
      partnerOwnershipPercentage:
          partnerOwnershipPercentage ?? this.partnerOwnershipPercentage,
      linkedLiabilityId: linkedLiabilityId ?? this.linkedLiabilityId,
      linkedLiabilityName: linkedLiabilityName ?? this.linkedLiabilityName,
      linkedLiabilityAmountZar:
          linkedLiabilityAmountZar ?? this.linkedLiabilityAmountZar,
      notes: notes ?? this.notes,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'category': category.name,
      'current_value_zar': currentValueZar,
      'acquisition_cost_zar': acquisitionCostZar,
      'acquisition_date': acquisitionDate.toIso8601String(),
      'depreciation_method': depreciationMethod.name,
      'useful_life_years': usefulLifeYears,
      'depreciation_rate_percent': depreciationRatePercent,
      'location': location,
      'registration_number': registrationNumber,
      'documentation_reference': documentationReference,
      'ownership_type': ownershipType.name,
      'my_ownership_percentage': myOwnershipPercentage,
      'partner_ownership_percentage': partnerOwnershipPercentage,
      'linked_liability_id': linkedLiabilityId,
      'linked_liability_name': linkedLiabilityName,
      'linked_liability_amount_zar': linkedLiabilityAmountZar,
      'notes': notes,
      'include_in_net_worth': includeInNetWorth ? 1 : 0,
      'currency_code': currencyCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AssetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AssetType.tangible,
      ),
      category: AssetCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => AssetCategory.other,
      ),
      currentValueZar: (json['current_value_zar'] as num?)?.toDouble() ?? 0.0,
      acquisitionCostZar: (json['acquisition_cost_zar'] as num?)?.toDouble() ?? 0.0,
      acquisitionDate: json['acquisition_date'] != null
          ? DateTime.tryParse(json['acquisition_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      depreciationMethod: DepreciationMethod.values.firstWhere(
        (e) => e.name == json['depreciation_method'],
        orElse: () => DepreciationMethod.none,
      ),
      usefulLifeYears: (json['useful_life_years'] as num?)?.toDouble() ?? 5.0,
      depreciationRatePercent:
          (json['depreciation_rate_percent'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] as String? ?? '',
      registrationNumber: json['registration_number'] as String? ?? '',
      documentationReference: json['documentation_reference'] as String? ?? '',
      ownershipType: OwnershipType.values.firstWhere(
        (e) => e.name == json['ownership_type'],
        orElse: () => OwnershipType.solo,
      ),
      myOwnershipPercentage:
          (json['my_ownership_percentage'] as num?)?.toDouble() ?? 100.0,
      partnerOwnershipPercentage:
          (json['partner_ownership_percentage'] as num?)?.toDouble() ?? 0.0,
      linkedLiabilityId: json['linked_liability_id'] as String?,
      linkedLiabilityName: json['linked_liability_name'] as String?,
      linkedLiabilityAmountZar:
          (json['linked_liability_amount_zar'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
      includeInNetWorth: json['include_in_net_worth'] == 1 ||
          json['include_in_net_worth'] == true ||
          json['include_in_net_worth'] == null,
      currencyCode: (json['currency_code'] ?? json['currencyCode'] ?? 'ZAR').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

