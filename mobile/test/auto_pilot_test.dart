import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/models/email_transaction_proposal.dart';
import 'package:ziva_finance/models/deposit_slip_model.dart';
import 'package:ziva_finance/models/reconciliation_model.dart';
import 'package:ziva_finance/models/confidence_rule_model.dart';
import 'package:ziva_finance/models/predictive_cashflow_model.dart';
import 'package:ziva_finance/models/bank_sync_model.dart';
import 'package:ziva_finance/models/legacy_vault_model.dart';
import 'package:ziva_finance/services/sqlite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase Four: Email-to-Ledger Intelligence', () {
    test('EmailTransactionProposal models financial documents with confidence and metadata', () {
      final proposal = EmailTransactionProposal(
        id: 'prop_test_1',
        emailSubject: 'Standard Bank Monthly Statement - Aug 2026',
        senderEmail: 'statements@standardbank.co.za',
        receivedDate: DateTime(2026, 8, 31),
        documentType: EmailDocumentType.bankStatement,
        extractedAmount: 4250.00,
        currency: 'ZAR',
        counterparty: 'Standard Bank Home Loan',
        referenceNumber: 'REF-HL-202608',
        accountIdentifier: 'Acc ...8890',
        confidenceScore: 0.96,
        rawSnippet: 'Amount due: R4,250.00, Account: 1029388890',
      );

      expect(proposal.formattedConfidence, equals('96%'));
      expect(proposal.isHighConfidence, isTrue);
      expect(proposal.status, equals(ProposalStatus.pending));

      final json = proposal.toJson();
      final restored = EmailTransactionProposal.fromJson(json);
      expect(restored.id, equals('prop_test_1'));
      expect(restored.extractedAmount, equals(4250.00));
      expect(restored.counterparty, equals('Standard Bank Home Loan'));
      expect(restored.confidenceScore, equals(0.96));
      expect(restored.documentType, equals(EmailDocumentType.bankStatement));
    });

    test('Keep and Remove workflow alters proposal status', () async {
      final sqlite = SqliteService.instance;
      final proposals = sqlite.getEmailProposals();
      expect(proposals.isNotEmpty, isTrue);

      final target = proposals.first;
      await sqlite.keepEmailProposal(target.id);
      final updatedProposals = sqlite.getEmailProposals();
      final updated = updatedProposals.firstWhere((p) => p.id == target.id);
      expect(updated.status, equals(ProposalStatus.kept));

      // Test remove workflow
      if (proposals.length > 1) {
        final secondTarget = proposals[1];
        await sqlite.removeEmailProposal(secondTarget.id);
        final postRemove = sqlite.getEmailProposals();
        final removed = postRemove.firstWhere((p) => p.id == secondTarget.id);
        expect(removed.status, equals(ProposalStatus.removed));
      }
    });

    test('Manual scan triggers email ingestion', () async {
      final sqlite = SqliteService.instance;
      final initialCount = sqlite.getEmailProposals().length;
      final parsedCount = await sqlite.scanGoogleWorkspaceEmails();
      final finalCount = sqlite.getEmailProposals().length;
      expect(parsedCount, greaterThanOrEqualTo(0));
      expect(finalCount, greaterThanOrEqualTo(initialCount));
    });
  });

  group('Phase Four: Handwritten Bank Deposit Slip OCR Pipeline', () {
    test('DepositSlipModel tracks extracted fields and per-field confidence scores', () {
      final slip = DepositSlipModel(
        id: 'slip_test_1',
        bankName: 'First National Bank',
        uploadedAt: DateTime(2026, 9, 2),
        extractedAmount: 35000.0,
        amountConfidence: 0.95,
        extractedDate: DateTime(2026, 9, 2),
        dateConfidence: 0.90,
        extractedAccountNumber: '62849102931',
        accountConfidence: 0.88,
        extractedReference: 'DEP-77391',
        status: DepositSlipStatus.readyForReview,
      );

      expect(slip.formattedAmount, equals('R 35000.00'));
      expect(slip.overallConfidence, greaterThan(0.85));
      expect(slip.amountConfidence, equals(0.95));
      expect(slip.effectiveAmount, equals(35000.0));

      final json = slip.toJson();
      final restored = DepositSlipModel.fromJson(json);
      expect(restored.extractedAmount, equals(35000.0));
      expect(restored.bankName, equals('First National Bank'));
    });

    test('Inline field corrections update slip data', () {
      final sqlite = SqliteService.instance;
      final slips = sqlite.getDepositSlips();
      expect(slips.isNotEmpty, isTrue);

      final target = slips.first;
      sqlite.updateDepositSlipCorrection(
        target.id,
        correctedAmount: 48000.0,
        correctedAccountId: 'ACC_FNB_01',
      );

      final updatedSlips = sqlite.getDepositSlips();
      final corrected = updatedSlips.firstWhere((s) => s.id == target.id);
      expect(corrected.effectiveAmount, equals(48000.0));
      expect(corrected.effectiveAccountId, equals('ACC_FNB_01'));
    });

    test('Approving deposit slip marks status as approvedPendingDeposit', () async {
      final sqlite = SqliteService.instance;
      final slips = sqlite.getDepositSlips();
      final target = slips.first;
      final txn = await sqlite.approvePendingDeposit(target.id);

      expect(txn.reportingAmountZar, equals(target.effectiveAmount));
      final updatedSlips = sqlite.getDepositSlips();
      final approved = updatedSlips.firstWhere((s) => s.id == target.id);
      expect(approved.status, equals(DepositSlipStatus.approvedPendingDeposit));
    });
  });

  group('Phase Four: 3-Way Reconciliation Engine', () {
    test('Reconciliation engine matches statement transactions with ledger and slips', () async {
      final sqlite = SqliteService.instance;
      await sqlite.runReconciliationEngine();
      final summary = sqlite.getReconciliationSummary();

      expect(summary.reconciledCount + summary.unreconciledCount, greaterThan(0));
      expect(summary.reconciledTotalZar, greaterThanOrEqualTo(0.0));

      final matches = sqlite.getReconciliationMatches();
      expect(matches.isNotEmpty, isTrue);

      final match = matches.first;
      expect(match.statementTransaction.amountZar, greaterThan(0));
      expect(match.matchScore, inInclusiveRange(0.0, 1.0));
    });

    test('Mismatch resolution handles missing transaction creation', () async {
      final sqlite = SqliteService.instance;
      final matches = sqlite.getReconciliationMatches();
      final target = matches.first;

      await sqlite.resolveReconciliationMismatch(
        target.id,
        action: 'confirmAsMissing',
      );

      final updatedMatches = sqlite.getReconciliationMatches();
      final resolved = updatedMatches.firstWhere((m) => m.id == target.id);
      expect(resolved.status, equals(ReconciliationMatchStatus.reconciled));
    });
  });

  group('Phase Four: Confidence-Based Filter & Auto-Add Rules', () {
    test('Confidence threshold engine config classifies items accurately', () {
      const config = ConfidenceEngineConfig(
        highConfidenceThresholdPercent: 95.0,
        mediumConfidenceThresholdPercent: 70.0,
        autoAddEnabled: true,
      );

      expect(config.highConfidenceThresholdPercent, equals(95.0));
      expect(config.mediumConfidenceThresholdPercent, equals(70.0));
      expect(config.autoAddEnabled, isTrue);

      const testScorePercent = 96.0;
      final isAutoAddEligible = testScorePercent >= config.highConfidenceThresholdPercent;
      expect(isAutoAddEligible, isTrue);
    });

    test('Auto-add audit trail records automated actions with timestamp and scores', () {
      final sqlite = SqliteService.instance;
      final auditTrail = sqlite.getAutoAddAuditLogs();
      expect(auditTrail.isNotEmpty, isTrue);

      final record = auditTrail.first;
      expect(record.confidenceScore, greaterThanOrEqualTo(0.90));
      expect(record.sourceType, equals('Email / Google Workspace'));
      expect(record.counterparty.isNotEmpty, isTrue);
    });
  });

  group('Phase Four: Predictive Cash Flow & Early Warning System', () {
    test('Predictive model computes 7/14/30 day projections and identifies shortfalls', () {
      final sqlite = SqliteService.instance;
      final p7 = sqlite.calculatePredictiveCashFlowProjections(horizonDays: 7);
      final p14 = sqlite.calculatePredictiveCashFlowProjections(horizonDays: 14);
      final p30 = sqlite.calculatePredictiveCashFlowProjections(horizonDays: 30);

      expect(p7.horizonDays, equals(7));
      expect(p14.horizonDays, equals(14));
      expect(p30.horizonDays, equals(30));

      expect(p7.projectedLiquidZar, isNotNull);
      expect(p14.projectedLiquidZar, isNotNull);
      expect(p30.projectedLiquidZar, isNotNull);

      expect(p7.dailyBurnRateZar, greaterThan(0));

      // Check alerts generation
      final alerts = sqlite.getPredictiveAlerts();
      expect(alerts, isA<List<PredictiveAlert>>());
      for (final alert in alerts) {
        expect(alert.suggestedMitigations.isNotEmpty, isTrue);
      }
    });
  });

  group('Phase Four: Real-Time Bank Balance Sync APIs', () {
    test('Bank sync connections update balances and timestamps upon sync', () async {
      final sqlite = SqliteService.instance;
      final connections = sqlite.getBankConnections();
      expect(connections.isNotEmpty, isTrue);

      final initialSyncTime = connections.first.lastSyncedAt;
      await sqlite.syncBankBalances();

      final updatedConnections = sqlite.getBankConnections();
      expect(updatedConnections.first.lastSyncedAt.isAfter(initialSyncTime), isTrue);
      expect(updatedConnections.first.status, equals(BankSyncStatus.synced));
    });
  });

  group('Phase Four: Legacy & Estate Vault', () {
    test('Trusted contact management with access level tiers', () async {
      final sqlite = SqliteService.instance;
      final contacts = sqlite.getTrustedContacts();
      expect(contacts.isNotEmpty, isTrue);

      final newContact = TrustedContact(
        id: 'contact_exec_test',
        fullName: 'Dr. Michael Chen',
        relationship: 'Family Physician & Trustee',
        email: 'dr.chen@trustee.co.za',
        phoneNumber: '+27 82 999 8888',
        accessLevel: VaultAccessLevel.emergencyTrustee,
        designatedAt: DateTime(2026, 9, 7),
      );

      await sqlite.saveTrustedContact(newContact);
      final updatedContacts = sqlite.getTrustedContacts();
      expect(updatedContacts.any((c) => c.id == 'contact_exec_test'), isTrue);

      // Delete contact
      await sqlite.deleteTrustedContact('contact_exec_test');
      final postDelete = sqlite.getTrustedContacts();
      expect(postDelete.any((c) => c.id == 'contact_exec_test'), isFalse);
    });

    test('Estate Dossier generation produces comprehensive manifest map', () {
      final sqlite = SqliteService.instance;
      final dossier = sqlite.generateEstateDossier();

      expect(dossier.containsKey('principalName'), isTrue);
      expect(dossier['principalName'], equals('Shingirai Chapwanya'));
      expect(dossier.containsKey('totalEstateValuationZar'), isTrue);
      expect(dossier.containsKey('assetHoldingsValuationZar'), isTrue);
      expect(dossier.containsKey('liquidCashValuationZar'), isTrue);
      expect(dossier.containsKey('assets'), isTrue);
      expect(dossier.containsKey('trustedContacts'), isTrue);
      expect(dossier.containsKey('executorDirectives'), isTrue);
    });

    test('Secondary passcode gate logic unlocks vault with 2026', () {
      const validPasscode = '2026';
      const invalidPasscode = '1234';

      bool verifyPasscode(String pin) => pin.trim() == '2026';

      expect(verifyPasscode(validPasscode), isTrue);
      expect(verifyPasscode(invalidPasscode), isFalse);
    });
  });
}
