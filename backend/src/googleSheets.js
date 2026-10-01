/**
 * googleSheets.js - Google Sheets Service Adapter for Ziva Finance
 * 
 * Provides ESM and CommonJS exports for Google Sheets API operations,
 * replacing direct BigQuery write/streaming operations with Google Sheets API writes.
 */

import sheetsService from '../services/googleSheetsService.js';

export const SHEETS_CONFIG = sheetsService.SHEETS_CONFIG;
export const TRANSACTION_HEADERS = sheetsService.TRANSACTION_HEADERS;
export const DEBT_HEADERS = sheetsService.DEBT_HEADERS;
export const appendRows = sheetsService.appendRows;
export const appendTransaction = sheetsService.appendTransaction;
export const appendDebt = sheetsService.appendDebt;
export const insertRows = sheetsService.insertRows;
export const ensureSheetHeaders = sheetsService.ensureSheetHeaders;
export const getExternalTableDdl = sheetsService.getExternalTableDdl;
export const formatTransactionRow = sheetsService.formatTransactionRow;
export const formatDebtRow = sheetsService.formatDebtRow;
export const getAccessToken = sheetsService.getAccessToken;
export const sheetsApiRequest = sheetsService.sheetsApiRequest;

export default sheetsService;
