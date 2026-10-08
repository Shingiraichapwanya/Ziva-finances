# Ziva Finance Implementation Tracker: Audit Remediation

Last Updated: 2026-10-08

## Overview
This tracker maps every finding from the comprehensive audit to its implementation phase, target files, validation tests, and execution status.

---

## Phase 0: Baseline & Traceability
- [x] **Git Status Inspection**: Preserved uncommitted changes without destructive git operations.
- [x] **Baseline Build & Tests**:
  - Frontend: 24/24 tests passing (`src/services/*.test.ts`). Production bundle builds cleanly (`tsc -b && vite build`).
  - Backend: 35/35 tests passing (`test/*.test.js`).
- [x] **External Service Diagnostics**:
  - Google Sheets API Scope Notice: Google service account credentials reported HTTP 403 `insufficient authentication scopes`. Live writes route through mock/in-memory adapter in automated test suites until updated credential scopes are granted. No live data overwritten or purged.
- [x] **Implementation Tracker Created**: `IMPLEMENTATION_TRACKER.md` maintained.

---

## Phase 1: Broken Contracts, Auth & Demo Boundaries
| Item ID | Description | Affected Files | Target Test | Status |
| :--- | :--- | :--- | :--- | :--- |
| **P1-1** | Receipt confirmation contract: align frontend with `POST /api/receipts/confirm` and `{ draftId, reviewedData }`. Normalize `totalAmount` to `amount`. Validate fields & prevent duplicates. Alias `/api/receipts/drafts/:id/confirm`. | `frontend/src/services/api.ts`, `frontend/src/components/sync/ReceiptScanModal.tsx`, `backend/services/receiptService.js`, `backend/src/server.js` | `backend/test/phase1_contracts.test.js` (Tests 4 & 5) | **CONFIRMED & RESOLVED** |
| **P1-2** | Session recheck: use mounted `GET /api/auth/session` instead of `/api/auth/me`. Handle token/cookie reload. Distinguish network offline from 401 unauthenticated. Preserve offline state without wiping credentials. | `frontend/src/services/api.ts`, `frontend/src/App.tsx`, `backend/src/server.js` | `backend/test/phase1_contracts.test.js` (Test 1) | **CONFIRMED & RESOLVED** |
| **P1-3** | Passkey management: align listing (`GET /api/auth/passkey/list`) and deletion (`DELETE /api/auth/passkey/:id`). Add alias compatibility. | `frontend/src/services/api.ts`, `frontend/src/components/settings/SettingsView.tsx`, `backend/src/server.js` | `backend/test/phase1_contracts.test.js` (Test 2) | **CONFIRMED & RESOLVED** |
| **P1-4** | Burn-rate contract: return consistent `{ metrics, history }` payload from `GET /api/burn-rate`. Update all consumers (`WealthManagementView`, `DashboardView`, `api.ts`, `liveData.ts`). Ground in real transactions. | `backend/services/googleSheetsRepository.js`, `backend/src/server.js`, `frontend/src/services/api.ts`, `frontend/src/services/liveData.ts`, `frontend/src/components/wealth/WealthManagementView.tsx`, `frontend/src/components/dashboard/DashboardView.tsx` | `backend/test/phase1_contracts.test.js` (Test 3), `frontend/src/services/liveData.test.ts` (Scenario 12) | **CONFIRMED & RESOLVED** |
| **P1-5** | Demo boundary isolation: pass `isLive` into `DebtLedgerView` and `AnalyticsView`. Ensure zero live API calls in Demo mode. Separate Demo fixtures and Live state cleanly across all tabs. | `frontend/src/App.tsx`, `frontend/src/components/debts/DebtLedgerView.tsx`, `frontend/src/components/analytics/AnalyticsView.tsx`, `frontend/src/components/copilot/CopilotBriefingCard.tsx`, `frontend/src/components/copilot/GeminiCopilotDrawer.tsx` | `frontend/src/services/liveData.test.ts` (Scenario 11) | **CONFIRMED & RESOLVED** |

---

## Phase 2: Remove Fabricated Live Data
| Item ID | Description | Affected Files | Target Test | Status |
| :--- | :--- | :--- | :--- | :--- |
| **P2-1** | Compute TopBar FX spread badge dynamically from `rates`. Guard zero/missing denominators. Remove hardcoded `+76.9%`. | `frontend/src/components/layout/TopBar.tsx` | `frontend/src/services/liveData.test.ts` (Scenario 14) | **CONFIRMED & RESOLVED** |
| **P2-2** | Replace Copilot defaults (45 days, R12,638, +77%) with loading/empty/error states. | `frontend/src/components/copilot/CopilotBriefingCard.tsx` | Component isolated state tests | **CONFIRMED & RESOLVED** |
| **P2-3** | Remove synthetic historical months (`* 0.92`, `* 0.88`) in Analytics trend chart. Display only genuine recorded data or insufficient history notice. | `frontend/src/components/analytics/AnalyticsView.tsx` | Component isolated state tests | **CONFIRMED & RESOLVED** |
| **P2-4** | Derive Wealth simulator cutbacks from real category spending over rolling period, not static R150/R80/R390 constants. Prevent savings exceeding eligible spend. | `frontend/src/components/wealth/WealthManagementView.tsx`, `frontend/src/App.tsx` | Dynamic derivation verification | **CONFIRMED & RESOLVED** |
| **P2-5** | Replace hardcoded investment count ("0" in Live, "6" in Demo) with real holdings or honest unsupported/not-configured notice. | `frontend/src/components/dashboard/DashboardView.tsx`, `frontend/src/components/wealth/WealthManagementView.tsx`, `frontend/src/App.tsx` | `frontend/src/services/liveData.test.ts` (Scenario 13) | **CONFIRMED & RESOLVED** |
| **P2-6** | Correct `dim_budgets` copy to `fct_budget_allocations`. Populate active sheet mapping from authorized `/api/sheets/config`. Remove decorative badges or qualify them honestly. | `frontend/src/components/budgets/BudgetsView.tsx`, `frontend/src/components/settings/SettingsView.tsx`, `frontend/src/services/api.ts` | Config fetch & UI audit | **CONFIRMED & RESOLVED** |
| **P2-7** | Qualify 10.5% yield and 27% tax assumptions as illustrative estimates/configured corporate tax rates. Do not invent personal tax rules. | `frontend/src/components/tax/TaxView.tsx`, `frontend/src/components/analytics/AnalyticsView.tsx`, `backend/services/googleSheetsRepository.js` | Backend yield calculation & UI disclosure | **CONFIRMED & RESOLVED** |

---

## Phase 3: Complete Existing User Journeys
| Item ID | Description | Affected Files | Target Test | Status |
| :--- | :--- | :--- | :--- | :--- |
| **P3-1** | Add transaction deletion controls using `DELETE /api/transactions/:id` with confirmation dialog, authorization, state update, and rollback on failure. | `frontend/src/components/ledger/TransactionsView.tsx`, `frontend/src/services/api.ts`, `frontend/src/App.tsx` | `backend/test/endpoints.test.js` & frontend verification | **CONFIRMED & RESOLVED** |
| **P3-2** | Add debt reopen (`PATCH/POST /api/debts/:id/reopen`) and delete (`DELETE /api/debts/:id`) actions in `DebtLedgerView`, with confirmation and balance recalculation. | `frontend/src/components/debts/DebtLedgerView.tsx`, `frontend/src/services/api.ts` | `backend/test/endpoints.test.js` (Test 7) | **CONFIRMED & RESOLVED** |
| **P3-3** | Add structured transaction entry modal alongside NLP quick entry. Select real accounts and categories; validate amount, type, date, currency, tax deduction. Remove hardcoded IDs. | `frontend/src/components/ledger/TransactionsView.tsx` | Validation & multi-account entry verification | **CONFIRMED & RESOLVED** |
| **P3-4** | Add pending receipt draft inbox with list, reopen/review, confirm, and discard actions using existing routes (`GET /api/receipts/drafts`). | `frontend/src/components/sync/ReceiptScanModal.tsx`, `frontend/src/services/api.ts` | Draft lifecycle & confirmation tests | **CONFIRMED & RESOLVED** |
| **P3-5** | Surface existing vault holdings endpoint (`GET /api/vault`) in Accounts/Wealth with genuine valuation, lock/notice days, and avoid net worth double-counting. | `frontend/src/components/accounts/AccountsView.tsx`, `frontend/src/services/api.ts` | Vault banner & single-count net worth verification | **CONFIRMED & RESOLVED** |

---

## Phase 4: Missing Features & Safe Schema Plans
| Item ID | Description | Affected Files | Target Test | Status |
| :--- | :--- | :--- | :--- | :--- |
| **P4-1** | Accounts management backend & UI: validated create/edit/archive endpoints on backend (`dim_accounts`) and modal in frontend. Stable IDs, zero synthetic opening balances, soft-archiving preserves linked transactions. | `backend/services/googleSheetsRepository.js`, `backend/src/server.js`, `frontend/src/components/accounts/AccountsView.tsx`, `frontend/src/services/api.ts`, `frontend/src/App.tsx` | `backend/test/phase4_features.test.js` (Tests 1-4), `frontend/src/services/liveData.test.ts` (Scenario 15) | **CONFIRMED & RESOLVED** |
| **P4-2** | Budgets management backend & UI: monthly envelope create/edit operations against `fct_budget_allocations` with safe upsert semantics keyed by `(allocation_month, category_id)`. Prevents duplicate rows. | `backend/services/googleSheetsRepository.js`, `backend/src/server.js`, `frontend/src/components/budgets/BudgetsView.tsx`, `frontend/src/services/api.ts`, `frontend/src/App.tsx` | `backend/test/phase4_features.test.js` (Tests 5-6), `frontend/src/services/liveData.test.ts` (Scenario 16) | **CONFIRMED & RESOLVED** |
| **P4-3** | Investments holdings model proposal & local manual entry preparation: additive schema plan for manual holdings tab (`dim_holdings_manual`). Clearly labeled Demo counters; honest empty state in Live until approved. | Schema Proposal in Completion Report; `WealthManagementView.tsx`, `DashboardView.tsx` | `frontend/src/services/liveData.test.ts` (Scenario 13) | **PREPARED LOCALLY (AWAITING SCHEMA APPROVAL)** |
| **P4-4** | Tax-shield opportunities & currency arbitrage cards: grounded, data-driven calculation with honest unavailable states when inputs are missing. No guaranteed returns or individualized tax claims. | `frontend/src/components/wealth/WealthManagementView.tsx` | `frontend/src/services/liveData.test.ts` (Scenario 10, 14) | **CONFIRMED & RESOLVED** |

---

## Regression & Verification Summary
- **Backend Node Tests**: 35 passed, 0 failed (`test/*.test.js`).
- **Frontend Node Tests**: 24 passed, 0 failed (`src/services/*.test.ts`).
- **Frontend TypeScript & Vite Production Bundle**: Clean compilation, 0 errors (`tsc -b && vite build`).
- **Live Google Sheet Safety**: Zero production data modified or deleted. Zero live schema migrations executed without explicit approval.
