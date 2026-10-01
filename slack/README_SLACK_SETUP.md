# Slack Integration & Natural Language Ingestion for BigQuery Budget Tracker

This directory contains the serverless Slack integration layer for the Personal Finance Budget Tracker on Google BigQuery (`budget-tracker-507418.personal_finance`).

---

## Architecture

```
┌─────────────────┐       /spend or @Mention        ┌───────────────────────────────────┐
│   Slack User    │ ──────────────────────────────► │ Google Apps Script (Web App)      │
└─────────────────┘                                 │  - Code.js (doPost routing)       │
         ▲                                          │  - Parser.js (NLP entity parser)  │
         │                                          │  - BigQueryClient.js (Ingestion)  │
         │ Rich Block Kit Response                  │  - SlackFormatter.js (Block UI)   │
         │ (Conversion, Envelope Status)            └─────────────────┬─────────────────┘
         │                                                            │
┌────────┴────────┐                                                   │ Writes Row via Sheets API
│ Slack Channel   │ ◄──────────────────────────────┐                  ▼
└─────────────────┘                                │  ┌───────────────────────────────────┐
                                                   │  │ Google Sheets Ingestion Layer     │
                                                   │  │  - fct_transactions tab          │
                                                   │  └─────────────────┬─────────────────┘
                                                   │                    │ Real-Time External Read
                                                   │                    ▼
                                                   │  ┌───────────────────────────────────┐
                                                   └─ │ Google BigQuery (External Table)  │
                                                      │  - fct_transactions (ext table)   │
                                                      │  - v_monthly_budget_vs_actual     │
                                                      │  - v_latest_effective_exchange_...│
                                                      └───────────────────────────────────┘
```

---

## Project Structure

| File | Purpose |
| :--- | :--- |
| `Parser.js` | Tokenizer & NLP parser. Extracts amounts, currencies (ZAR, USD, ZiG), merchant, notes, and maps to warehouse dimensions & cash-flow tiers. |
| `BigQueryClient.js` | Ingestion & query integration. Normalizes currency rates, appends transactions directly to Google Sheets (`fct_transactions`) via Sheets API, and queries live budget metrics via BigQuery external table. |
| `SlackFormatter.js` | Generates Slack Block Kit UI components: transaction cards, visual budget progress bar (`🟢 On Track`, `🟡 Near Limit`, `🔴 OVER BUDGET`), and error/help views. |
| `Code.js` | Master Google Apps Script entry point. Handles `doPost(e)` for Slash commands (`/spend`) and Event API callbacks (`@BudgetBot`), plus `doGet(e)` health checks. |
| `appsscript.json` | Apps Script manifest defining the V8 runtime, BigQuery v2 & Sheets v4 advanced services, and required OAuth scopes (BigQuery, Sheets, Drive). |
| `slack_app_manifest.json` | Ready-to-use Slack App Manifest for 1-click import in the Slack API console. |
| `tests/` | Automated unit tests for parser and Block Kit formatting (`test_parser.js`, `test_formatter_and_flow.js`). |

---

## Step-by-Step Deployment Guide

### Step 1: Create the Google Apps Script Project

1. Open [script.google.com](https://script.google.com) while signed into the same Google Account that owns GCP project `budget-tracker-507418`.
2. Click **New Project** and name it `BigQuery Personal Finance Slack Bot`.
3. In the left sidebar, click **Project Settings** (gear icon ⚙️):
   - Check the box **Show "appsscript.json" manifest file in editor**.
   - Under **Google Cloud Platform (GCP) Project**, click **Change project**, enter standard project number or project ID `budget-tracker-507418`, and link it.
4. In the editor view, create/paste the contents of each file from this directory:
   - `appsscript.json` (replace existing content)
   - `Code.gs` (paste content from `Code.js`)
   - `Parser.gs` (paste content from `Parser.js`)
   - `BigQueryClient.gs` (paste content from `BigQueryClient.js`)
   - `SlackFormatter.gs` (paste content from `SlackFormatter.js`)
5. In the left sidebar under **Services**, verify **BigQuery** is listed. (If not, click `+`, select **BigQuery API**, and click **Add**).

### Step 2: Deploy as a Web App

1. In the Apps Script editor, click **Deploy** (top right) > **New deployment**.
2. Select type **Web app** (click the gear icon next to "Select type" if prompted).
3. Fill in the fields:
   - **Description**: `Production v1`
   - **Execute as**: `Me (your_email@gmail.com)`
   - **Who has access**: `Anyone` *(Slack webhooks need to send HTTP POST without Google login prompts)*
4. Click **Deploy**.
5. Grant permissions if prompted (review and approve access to BigQuery and external requests).
6. Copy the generated **Web App URL** (format: `https://script.google.com/macros/s/AKfycb.../exec`).

### Step 3: Create & Configure the Slack App

1. Open the [Slack API Console](https://api.slack.com/apps).
2. Click **Create New App** > **From an app manifest**.
3. Select your Slack workspace.
4. Copy the contents of [`slack_app_manifest.json`](file:///C:/Users/shing/.gemini/antigravity-ide/scratch/personal-budget-tracker-bigquery/slack/slack_app_manifest.json).
5. In the manifest editor, replace the two occurrences of:
   ```
   https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec
   ```
   with your actual Apps Script **Web App URL** copied from Step 2.
6. Click **Next** and then **Create**.
7. Click **Install to Workspace** and authorize the bot.

### Step 4 (Optional): Bot Mention Support (`@BudgetBot`)

If you want users to log spending by mentioning `@BudgetBot` directly in channels (in addition to the `/spend` slash command):
1. In the Slack API console, navigate to **OAuth & Permissions**.
2. Copy the **Bot User OAuth Token** (starts with `xoxb-...`).
3. In Google Apps Script > **Project Settings** > **Script Properties**, add:
   - **Property**: `SLACK_BOT_TOKEN`
   - **Value**: `xoxb-...` (your token)
4. Invite `@BudgetBot` into your finance Slack channel (`/invite @BudgetBot`).

---

## Usage Examples

### 1. Daily Expenses (Tier 1: Capitec ZAR / EcoCash USD & ZiG)
```slack
/spend Spent 50 ZAR on lunch at Vida
/spend Paid 120 USD for OK Mart groceries
/spend Coffee R45 at Vida e Caffe
/spend 245 ZiG airtime Econet
/spend 150 ZAR Uber ride to airport
```

### 2. Monthly Fixed Allocations (Tier 2: FNB ZAR / Stanbic Nostro USD)
```slack
/spend Rent 14500 ZAR apartment lease
/spend Paid 100 USD for ZESA power token
/spend Dis-Chem pharmacy 450 ZAR meds
/spend Netflix subscription 199 ZAR
```

### 3. Vault & Investments (Tier 3: EasyEquities ZAR / Old Mutual USD)
```slack
/spend Invested 8000 ZAR in S&P500 ETF
```

### 4. Income Logging
```slack
/spend Salary received 55000 ZAR client retainer
/spend Consulting invoice paid 1500 USD
```

### 5. Help Reference
```slack
/spend help
```

---

## BigQuery Sandbox Compatibility

> [!NOTE]
> When running BigQuery in the **Free Tier Sandbox** without a linked Cloud Billing account, SQL `INSERT INTO` DML statements are restricted by Google Cloud. 
> 
> `BigQueryClient.js` automatically uses **BigQuery Load Jobs (`BigQuery.Jobs.insert`)** with newline-delimited JSON payloads. BigQuery Load Jobs are **100% free and fully functional in Sandbox mode**, ensuring zero interruption or billing requirements. If billing is enabled in the future, the client also includes a seamless DML fallback.
