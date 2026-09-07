# BigQuery Service Account Credentials

This directory (`assets/credentials/`) is configured in `pubspec.yaml` to allow the mobile app to load service account credentials for Google Cloud BigQuery.

## Active Service Account Details
- **Service Account Name**: `mobile-bigquery-client`
- **Email**: `mobile-bigquery-client@budget-tracker-507418.iam.gserviceaccount.com`
- **GCP Project**: `budget-tracker-507418`
- **Assigned IAM Roles**:
  - `roles/bigquery.dataEditor` (Full read/write on BigQuery datasets and tables)
  - `roles/bigquery.jobUser` (Submitting BigQuery SQL query jobs)

## GCP Organization Policy Note
The project has the organization policy constraint `constraints/iam.disableServiceAccountKeyCreation` enforced (`enforced: true`). 
For security compliance in production environments, Google Cloud disables the export and downloading of private service account JSON keys to client-side bundles.

If key creation is explicitly permitted in your organization:
1. Have an Org Policy Admin run:
   ```bash
   gcloud resource-manager org-policies disable-enforce constraints/iam.disableServiceAccountKeyCreation --project=budget-tracker-507418
   ```
2. Generate the key:
   ```bash
   gcloud iam service-accounts keys create mobile/assets/credentials/mobile-bigquery-client.json --iam-account=mobile-bigquery-client@budget-tracker-507418.iam.gserviceaccount.com --project=budget-tracker-507418
   ```

## Production Security Architecture
In standard production architectures, mobile clients do not bundle static service account private keys (which can be reverse-engineered). Instead, the mobile client communicates through the Ziva Finance backend API server (`backend/`), which authenticates against BigQuery using Application Default Credentials (ADC) or Workload Identity.
