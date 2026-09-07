import 'package:flutter/foundation.dart';

/// Receipt Storage Reference Service
///
/// Encapsulates storage references for audit receipts without storing raw files
/// in the ledger database. Integrates with cloud bucket storage conventions.
class ReceiptStorageService {
  static final ReceiptStorageService instance = ReceiptStorageService._internal();
  ReceiptStorageService._internal();

  static const String _gcsBucketBase = 'https://storage.googleapis.com/budget-tracker-507418-receipts/tax_2026';

  /// Determines whether a given filename or mimeType corresponds to a PDF or Image
  String? detectFileType(String? filename, [String? mimeType]) {
    if (mimeType != null && mimeType.isNotEmpty) {
      final cleanMime = mimeType.toLowerCase();
      if (cleanMime.contains('pdf')) return 'pdf';
      if (cleanMime.contains('image') || cleanMime.contains('png') || cleanMime.contains('jpeg') || cleanMime.contains('jpg')) {
        return 'image';
      }
    }

    if (filename != null && filename.isNotEmpty) {
      final lower = filename.toLowerCase();
      if (lower.endsWith('.pdf')) return 'pdf';
      if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
        return 'image';
      }
    }

    return null;
  }

  /// Generates a standardized audit storage URL reference for an uploaded receipt
  String generateStorageUrl({
    required String transactionId,
    required String filename,
  }) {
    final sanitizedFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$_gcsBucketBase/${transactionId}_$sanitizedFilename';
  }

  /// Formats and validates a receipt reference object
  ReceiptStorageReference saveReceiptReference({
    required String transactionId,
    required String filename,
    String? existingUrl,
    String? mimeType,
  }) {
    final fileType = detectFileType(filename, mimeType);
    final storageUrl = existingUrl != null && existingUrl.isNotEmpty
        ? existingUrl
        : generateStorageUrl(transactionId: transactionId, filename: filename);

    debugPrint('[ReceiptStorageService] Registered receipt reference: $storageUrl ($fileType)');

    return ReceiptStorageReference(
      storageUrl: storageUrl,
      fileType: fileType,
      fileName: filename,
    );
  }
}

class ReceiptStorageReference {
  final String storageUrl;
  final String? fileType; // 'pdf' | 'image' | null
  final String fileName;

  const ReceiptStorageReference({
    required this.storageUrl,
    required this.fileType,
    required this.fileName,
  });
}
