import React, { useState, useRef, useEffect } from 'react';
import {
  X,
  Camera,
  Upload,
  CheckCircle2,
  FileText,
  AlertTriangle,
  RotateCcw,
  Sparkles,
  ArrowRight,
  ShieldCheck,
  HardDrive,
  Trash2,
  Loader2,
  Inbox
} from 'lucide-react';
import { Transaction, CurrencyCode } from '../../types/finance';
import { financeApi, ReceiptDraft } from '../../services/api';

interface ReceiptScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSaveReceiptTransaction: (tx: Transaction) => void;
}

export const ReceiptScanModal: React.FC<ReceiptScanModalProps> = ({
  isOpen,
  onClose,
  onSaveReceiptTransaction
}) => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isConfirming, setIsConfirming] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Active Draft state returned from OCR upload
  const [activeDraft, setActiveDraft] = useState<ReceiptDraft | null>(null);

  // Inbox & Pending Drafts State
  const [modalTab, setModalTab] = useState<'scan' | 'inbox'>('scan');
  const [pendingDrafts, setPendingDrafts] = useState<ReceiptDraft[]>([]);
  const [isLoadingDrafts, setIsLoadingDrafts] = useState(false);

  // Editable Form fields populated from OCR
  const [merchant, setMerchant] = useState('');
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState<CurrencyCode>('ZAR');
  const [txDate, setTxDate] = useState(new Date().toISOString().split('T')[0]);
  const [invoiceNumber, setInvoiceNumber] = useState('');
  const [accountId, setAccountId] = useState('ACC_ZA_CAPITEC_DAILY');
  const [categoryId, setCategoryId] = useState('CAT_PROD_TECH_HARDWARE');
  const [isTaxDeductible, setIsTaxDeductible] = useState(true);

  // Success Confirmation state
  const [confirmedTxId, setConfirmedTxId] = useState<string | null>(null);

  const cameraInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const loadDrafts = async () => {
    setIsLoadingDrafts(true);
    try {
      const drafts = await financeApi.getReceiptDrafts();
      setPendingDrafts(drafts || []);
    } catch (err) {
      console.warn('Could not load receipt drafts:', err);
    } finally {
      setIsLoadingDrafts(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      loadDrafts();
    }
  }, [isOpen]);

  const handleSelectDraft = (draft: ReceiptDraft) => {
    setActiveDraft(draft);
    setMerchant(draft.extractedData.merchant || 'Unknown Merchant');
    setAmount(draft.extractedData.totalAmount ? String(draft.extractedData.totalAmount) : '');
    const cur = (draft.extractedData.currency as CurrencyCode) || 'ZAR';
    setCurrency(['ZAR', 'USD', 'ZiG'].includes(cur) ? cur : 'ZAR');
    setTxDate(draft.extractedData.date || new Date().toISOString().split('T')[0]);
    setInvoiceNumber(draft.extractedData.invoiceNumber || '');
    if (cur === 'USD') setAccountId('ACC_ZW_ECOCASH_USD');
    else if (cur === 'ZiG') setAccountId('ACC_ZW_ECOCASH_ZIG');
    else setAccountId('ACC_ZA_CAPITEC_DAILY');
    if (draft.fileReference.driveWebViewLink) {
      setPreviewUrl(draft.fileReference.driveWebViewLink);
    } else {
      setPreviewUrl(null);
    }
    setModalTab('scan');
  };

  const handleDiscardSpecificDraft = async (draftId: string) => {
    if (!window.confirm('Are you sure you want to discard this pending draft?')) return;
    try {
      await financeApi.deleteReceiptDraft(draftId);
      setPendingDrafts((prev) => prev.filter((d) => d.draftId !== draftId));
      if (activeDraft?.draftId === draftId) {
        resetState();
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to delete draft');
    }
  };

  if (!isOpen) return null;

  const resetState = () => {
    setSelectedFile(null);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setIsProcessing(false);
    setIsConfirming(false);
    setErrorMessage(null);
    setActiveDraft(null);
    setConfirmedTxId(null);
    setMerchant('');
    setAmount('');
    setCurrency('ZAR');
    setTxDate(new Date().toISOString().split('T')[0]);
    setInvoiceNumber('');
  };

  const handleClose = () => {
    resetState();
    onClose();
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      setErrorMessage('File size exceeds 10 MB limit. Please select a smaller receipt image or PDF.');
      return;
    }

    setErrorMessage(null);
    setSelectedFile(file);

    if (file.type.startsWith('image/')) {
      const url = URL.createObjectURL(file);
      setPreviewUrl(url);
    } else {
      setPreviewUrl(null);
    }
  };

  const handleUploadAndAnalyze = async () => {
    if (!selectedFile) return;

    setIsProcessing(true);
    setErrorMessage(null);

    try {
      const res = await financeApi.uploadReceipt(selectedFile);
      const draft = res.draft;
      setActiveDraft(draft);

      // Populate editable fields from draft OCR extraction
      setMerchant(draft.extractedData.merchant || 'Unknown Merchant');
      setAmount(draft.extractedData.totalAmount ? String(draft.extractedData.totalAmount) : '');
      const cur = (draft.extractedData.currency as CurrencyCode) || 'ZAR';
      setCurrency(['ZAR', 'USD', 'ZiG'].includes(cur) ? cur : 'ZAR');
      setTxDate(draft.extractedData.date || new Date().toISOString().split('T')[0]);
      setInvoiceNumber(draft.extractedData.invoiceNumber || '');

      // Suggest appropriate default account based on currency
      if (cur === 'USD') setAccountId('ACC_ZW_ECOCASH_USD');
      else if (cur === 'ZiG') setAccountId('ACC_ZW_ECOCASH_ZIG');
      else setAccountId('ACC_ZA_CAPITEC_DAILY');
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to process receipt. Please try another image.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDiscardDraft = async () => {
    if (activeDraft) {
      try {
        await financeApi.deleteReceiptDraft(activeDraft.draftId);
      } catch (err) {
        console.warn('Failed to delete draft on server:', err);
      }
    }
    resetState();
  };

  const handleConfirmAndPost = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeDraft) return;

    const num = parseFloat(amount);
    if (isNaN(num) || num <= 0) {
      setErrorMessage('Please enter a valid receipt amount greater than 0.');
      return;
    }

    setIsConfirming(true);
    setErrorMessage(null);

    try {
      const overrides = {
        merchant: merchant.trim(),
        totalAmount: num,
        currency,
        date: txDate,
        invoiceNumber: invoiceNumber.trim(),
        accountId,
        categoryId,
        isTaxDeductible
      };

      const res = await financeApi.confirmReceiptDraft(activeDraft.draftId, overrides);
      setConfirmedTxId(res.transactionId);

      // Build Transaction record for instant UI state update
      const newTx: Transaction = {
        transactionId: res.transactionId,
        transactionTimestamp: new Date().toISOString(),
        transactionDate: txDate,
        localTimezone: 'Africa/Johannesburg',
        accountId,
        cashFlowTier: 'DAILY_SPENDING',
        categoryId,
        categoryName: categoryId === 'CAT_PROD_TECH_HARDWARE' ? 'Productivity Tech & Work Hardware' : 'Operational Expense',
        transactionType: 'EXPENSE',
        originalAmount: -num,
        originalCurrency: currency,
        reportingAmountUsd: currency === 'USD' ? -num : -num * (1 / 18.25),
        reportingAmountZar: currency === 'ZAR' ? -num : -num * 18.25,
        appliedExchangeRateUsd: 1 / 18.25,
        appliedExchangeRateZar: 1.0,
        rateTypeApplied: 'OFFICIAL_INTERBANK',
        merchantOrPayee: merchant.trim(),
        paymentMethod: 'DEBIT_CARD',
        isTaxDeductible,
        taxDeductibleAmountZar: isTaxDeductible ? num : undefined,
        taxInvoiceNumber: invoiceNumber.trim() || undefined,
        tags: ['receipt-scan', currency.toLowerCase(), isTaxDeductible ? 'tax-deductible' : 'personal'],
        isSynced: true
      };

      onSaveReceiptTransaction(newTx);
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to save confirmed transaction to Google Sheets.');
    } finally {
      setIsConfirming(false);
    }
  };

  return (
    <div className="modal-backdrop animate-fade-in" onClick={handleClose}>
      <div
        className="glass-panel modal-card"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: activeDraft ? 820 : 540 }}
      >
        {/* Modal Header */}
        <div className="modal-header">
          <div className="modal-title-wrap">
            <Camera size={20} className="text-gold" />
            <div>
              <h3 style={{ margin: 0 }}>Scan & Archive Receipt</h3>
              <span className="text-xs text-muted">
                {confirmedTxId
                  ? 'Transaction Saved to Google Sheets'
                  : activeDraft
                  ? 'Step 2: Review & Confirm Extracted Draft'
                  : 'Step 1: Capture or Select Receipt Document'}
              </span>
            </div>
          </div>
          <button type="button" className="btn-close" onClick={handleClose}>
            <X size={18} />
          </button>
        </div>

        {/* Modal Body */}
        <div className="modal-body" style={{ maxHeight: '82vh', overflowY: 'auto' }}>
          {errorMessage && (
            <div
              className="alert-banner"
              style={{
                background: 'rgba(239, 68, 68, 0.15)',
                border: '1px solid rgba(239, 68, 68, 0.4)',
                borderRadius: '8px',
                padding: '0.75rem',
                color: '#fca5a5',
                fontSize: '0.85rem',
                display: 'flex',
                gap: '0.5rem',
                marginBottom: '1rem'
              }}
            >
              <AlertTriangle size={16} style={{ flexShrink: 0, marginTop: 2 }} />
              <div>{errorMessage}</div>
            </div>
          )}

          {/* Hidden HTML5 File Inputs */}
          <input
            ref={cameraInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            style={{ display: 'none' }}
            onChange={handleFileSelect}
          />
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,application/pdf"
            style={{ display: 'none' }}
            onChange={handleFileSelect}
          />

          {/* STATE 3: Success Confirmation */}
          {confirmedTxId ? (
            <div style={{ textAlign: 'center', padding: '2rem 1rem' }}>
              <div
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: '50%',
                  background: 'rgba(16, 185, 129, 0.15)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  margin: '0 auto 1.25rem'
                }}
              >
                <CheckCircle2 size={32} className="text-emerald" />
              </div>
              <h4 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>Receipt Transaction Confirmed!</h4>
              <p className="text-muted" style={{ fontSize: '0.9rem', maxWidth: 420, margin: '0 auto 1.5rem' }}>
                Successfully recorded in Google Sheets <span className="mono">fct_transactions</span> and permanently archived in your private storage.
              </p>
              <div
                className="glass-panel mono"
                style={{
                  padding: '0.75rem',
                  fontSize: '0.85rem',
                  display: 'inline-block',
                  marginBottom: '1.5rem',
                  color: '#10b981'
                }}
              >
                ID: {confirmedTxId}
              </div>
              <div>
                <button type="button" className="btn btn-primary" onClick={handleClose}>
                  Done
                </button>
              </div>
            </div>
          ) : activeDraft ? (
            /* STATE 2: Side-by-side Review & Confirm */
            <form onSubmit={handleConfirmAndPost}>
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: previewUrl ? '1fr 1.2fr' : '1fr',
                  gap: '1.5rem',
                  alignItems: 'start'
                }}
              >
                {/* Left Column: Receipt Document Preview & Storage Info */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                  <div
                    className="glass-panel"
                    style={{
                      borderRadius: '8px',
                      overflow: 'hidden',
                      maxHeight: 380,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      background: 'rgba(0,0,0,0.3)',
                      border: '1px solid rgba(255,255,255,0.08)'
                    }}
                  >
                    {previewUrl ? (
                      <img
                        src={previewUrl}
                        alt="Receipt preview"
                        style={{ width: '100%', height: 'auto', maxHeight: 380, objectFit: 'contain' }}
                      />
                    ) : (
                      <div style={{ padding: '3rem 1rem', textAlign: 'center' }}>
                        <FileText size={48} className="text-gold" style={{ margin: '0 auto 0.5rem' }} />
                        <span className="mono text-xs text-muted">
                          {activeDraft.fileReference.originalFilename}
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Storage Reference Badge */}
                  <div
                    className="glass-panel"
                    style={{
                      padding: '0.65rem 0.85rem',
                      fontSize: '0.75rem',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.5rem'
                    }}
                  >
                    {activeDraft.storageDestination === 'GOOGLE_DRIVE_PRIVATE' ? (
                      <>
                        <ShieldCheck size={16} className="text-emerald" />
                        <div>
                          <strong>Private Google Drive:</strong> Folder Archive
                        </div>
                      </>
                    ) : (
                      <>
                        <HardDrive size={16} className="text-gold" />
                        <div>
                          <strong>Encrypted Local Storage:</strong> Ready for Drive Sync
                        </div>
                      </>
                    )}
                  </div>

                  {/* Confidence Badge */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', color: '#888' }}>
                    <span>OCR Model: Tesseract (Free Local)</span>
                    <span
                      style={{
                        color:
                          activeDraft.extractedData.confidence === 'HIGH'
                            ? '#10b981'
                            : activeDraft.extractedData.confidence === 'MEDIUM'
                            ? '#38bdf8'
                            : '#f59e0b',
                        fontWeight: 600
                      }}
                    >
                      Confidence: {activeDraft.extractedData.confidence}
                    </span>
                  </div>
                </div>

                {/* Right Column: Editable Draft Fields */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                  <div
                    style={{
                      background: 'rgba(234, 179, 8, 0.1)',
                      border: '1px solid rgba(234, 179, 8, 0.25)',
                      borderRadius: '6px',
                      padding: '0.5rem 0.75rem',
                      fontSize: '0.8rem',
                      color: '#fef08a'
                    }}
                  >
                    <strong>DRAFT AWAITING CONFIRMATION:</strong> Review extracted values below. No changes will be written to Google Sheets until you confirm.
                  </div>

                  <div className="form-col">
                    <label className="form-label">Merchant / Payee</label>
                    <input
                      type="text"
                      className="form-input"
                      value={merchant}
                      onChange={(e) => setMerchant(e.target.value)}
                      required
                    />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '0.75rem' }}>
                    <div className="form-col">
                      <label className="form-label">Total Amount</label>
                      <input
                        type="number"
                        step="0.01"
                        className="form-input mono"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        placeholder="0.00"
                        required
                      />
                    </div>
                    <div className="form-col">
                      <label className="form-label">Currency</label>
                      <select
                        className="form-input mono"
                        value={currency}
                        onChange={(e) => setCurrency(e.target.value as CurrencyCode)}
                      >
                        <option value="ZAR">🇿🇦 ZAR</option>
                        <option value="USD">🇺🇸 USD</option>
                        <option value="ZiG">🇿🇼 ZiG</option>
                      </select>
                    </div>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                    <div className="form-col">
                      <label className="form-label">Date</label>
                      <input
                        type="date"
                        className="form-input mono"
                        value={txDate}
                        onChange={(e) => setTxDate(e.target.value)}
                        required
                      />
                    </div>
                    <div className="form-col">
                      <label className="form-label">Tax Invoice Reference</label>
                      <input
                        type="text"
                        className="form-input mono"
                        value={invoiceNumber}
                        onChange={(e) => setInvoiceNumber(e.target.value)}
                        placeholder="INV-XXXXX"
                      />
                    </div>
                  </div>

                  <div className="form-col">
                    <label className="form-label">Payment Account</label>
                    <select
                      className="form-input"
                      value={accountId}
                      onChange={(e) => setAccountId(e.target.value)}
                    >
                      <option value="ACC_ZA_CAPITEC_DAILY">Capitec Bank (Daily Spending ZAR)</option>
                      <option value="ACC_ZW_ECOCASH_USD">EcoCash USD (Zimbabwe Liquid)</option>
                      <option value="ACC_ZW_ECOCASH_ZIG">EcoCash ZiG (Zimbabwe Daily)</option>
                      <option value="ACC_ZA_FNB_STAGING">FNB Cheque (Monthly Staging)</option>
                    </select>
                  </div>

                  <div className="form-col">
                    <label className="form-label">Expense Category</label>
                    <select
                      className="form-input"
                      value={categoryId}
                      onChange={(e) => setCategoryId(e.target.value)}
                    >
                      <option value="CAT_PROD_TECH_HARDWARE">Productivity Tech & Work Hardware</option>
                      <option value="CAT_SOFTWARE_SUBSCRIPTIONS">Software & Cloud Services</option>
                      <option value="CAT_OPS_OFFICE_SUPPLIES">Office Supplies & Logistics</option>
                      <option value="CAT_MEALS_SUBSISTENCE">Meals & Subsistence</option>
                      <option value="CAT_TRAVEL_LOGISTICS">Travel & Transport</option>
                      <option value="CAT_DAILY_INCIDENTAL">Micro-Cash & Incidentals</option>
                    </select>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem', marginTop: '0.25rem' }}>
                    <input
                      type="checkbox"
                      id="tax-deductible-check"
                      checked={isTaxDeductible}
                      onChange={(e) => setIsTaxDeductible(e.target.checked)}
                      style={{ cursor: 'pointer', width: 16, height: 16 }}
                    />
                    <label
                      htmlFor="tax-deductible-check"
                      style={{ fontSize: '0.85rem', cursor: 'pointer', userSelect: 'none' }}
                    >
                      Tag as Tax-Deductible Business Expense
                    </label>
                  </div>

                  {/* Actions */}
                  <div
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      gap: '0.75rem',
                      marginTop: '1rem',
                      paddingTop: '0.75rem',
                      borderTop: '1px solid rgba(255,255,255,0.08)'
                    }}
                  >
                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={handleDiscardDraft}
                      disabled={isConfirming}
                      style={{ gap: '0.4rem', color: '#fca5a5' }}
                    >
                      <Trash2 size={15} />
                      <span>Discard Draft</span>
                    </button>

                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={handleClose}
                      disabled={isConfirming}
                      title="Keep this draft in your inbox to finish later"
                    >
                      Keep for Later
                    </button>

                    <button
                      type="submit"
                      className="btn btn-primary"
                      disabled={isConfirming}
                      style={{ gap: '0.5rem' }}
                    >
                      {isConfirming ? (
                        <>
                          <Loader2 size={16} className="animate-spin" />
                          <span>Posting to Sheets…</span>
                        </>
                      ) : (
                        <>
                          <CheckCircle2 size={16} />
                          <span>Confirm & Post to Google Sheets</span>
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </div>
            </form>
          ) : (
            /* STATE 1: Capture or Upload Document / Inbox */
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              {/* Tab Selector: Upload vs Inbox */}
              <div style={{ display: 'flex', gap: '0.5rem', borderBottom: '1px solid rgba(255,255,255,0.08)', paddingBottom: '0.75rem' }}>
                <button
                  type="button"
                  className={`filter-pill-sm ${modalTab === 'scan' ? 'active' : ''}`}
                  onClick={() => setModalTab('scan')}
                  style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}
                >
                  <Camera size={14} />
                  <span>Capture & Upload</span>
                </button>
                <button
                  type="button"
                  className={`filter-pill-sm ${modalTab === 'inbox' ? 'active' : ''}`}
                  onClick={() => { setModalTab('inbox'); loadDrafts(); }}
                  style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}
                >
                  <Inbox size={14} />
                  <span>Pending Drafts Inbox ({pendingDrafts.length})</span>
                </button>
              </div>

              {modalTab === 'inbox' ? (
                /* INBOX VIEW */
                <div>
                  <div style={{ fontSize: '0.75rem', color: '#94a3b8', background: 'rgba(255,255,255,0.02)', padding: '0.5rem 0.75rem', borderRadius: '6px', marginBottom: '1rem', lineHeight: 1.4 }}>
                    ℹ️ <strong>Storage Durability Notice:</strong> Drafts reside in local server in-memory storage while awaiting confirmation. Review and confirm drafts to permanently commit them to Google Sheets.
                  </div>

                  {isLoadingDrafts ? (
                    <div style={{ textAlign: 'center', padding: '2.5rem' }}>
                      <Loader2 size={24} className="animate-spin text-gold" style={{ margin: '0 auto' }} />
                      <div className="text-muted text-xs" style={{ marginTop: '0.5rem' }}>Loading pending drafts…</div>
                    </div>
                  ) : pendingDrafts.length === 0 ? (
                    <div className="glass-panel" style={{ padding: '2.5rem 1rem', textAlign: 'center', borderRadius: '8px' }}>
                      <Inbox size={36} className="text-muted" style={{ margin: '0 auto 0.5rem', opacity: 0.5 }} />
                      <h4 style={{ fontSize: '1rem', marginBottom: '0.25rem' }}>Inbox is Clean</h4>
                      <p className="text-muted text-xs" style={{ margin: 0 }}>
                        No pending receipt drafts. Scanned receipts left unconfirmed will appear here.
                      </p>
                    </div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                      {pendingDrafts.map((draft) => (
                        <div
                          key={draft.draftId}
                          className="glass-panel"
                          style={{
                            padding: '0.9rem 1rem',
                            borderRadius: '8px',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            border: '1px solid rgba(255,255,255,0.06)'
                          }}
                        >
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '0.95rem' }}>
                              {draft.extractedData.merchant || 'Pending Receipt'}
                            </div>
                            <div className="mono text-muted text-xs" style={{ marginTop: '0.2rem' }}>
                              {draft.extractedData.currency || 'ZAR'} {draft.extractedData.totalAmount ? Number(draft.extractedData.totalAmount).toFixed(2) : '—'} • {draft.extractedData.date || 'No Date'}
                            </div>
                            {draft.extractedData.invoiceNumber && (
                              <div className="mono text-xs text-purple" style={{ marginTop: '0.15rem' }}>
                                Ref: {draft.extractedData.invoiceNumber}
                              </div>
                            )}
                          </div>
                          <div style={{ display: 'flex', gap: '0.5rem' }}>
                            <button
                              type="button"
                              className="btn btn-secondary"
                              onClick={() => handleDiscardSpecificDraft(draft.draftId)}
                              style={{ padding: '0.4rem 0.6rem', color: '#fca5a5' }}
                              title="Discard draft"
                            >
                              <Trash2 size={14} />
                            </button>
                            <button
                              type="button"
                              className="btn btn-primary"
                              onClick={() => handleSelectDraft(draft)}
                              style={{ padding: '0.4rem 0.8rem', fontSize: '0.8rem', gap: '0.35rem' }}
                            >
                              <span>Review & Post</span>
                              <ArrowRight size={13} />
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ) : (
                /* SCAN / UPLOAD VIEW */
                <>
                  <div
                    style={{
                      border: '2px dashed rgba(255, 255, 255, 0.15)',
                      borderRadius: '12px',
                      padding: '2rem 1rem',
                      textAlign: 'center',
                      background: 'rgba(255, 255, 255, 0.02)'
                    }}
                  >
                    {previewUrl ? (
                      <div style={{ maxWidth: 300, margin: '0 auto' }}>
                        <img
                          src={previewUrl}
                          alt="Selected preview"
                          style={{ width: '100%', maxHeight: 220, objectFit: 'contain', borderRadius: 8 }}
                        />
                        <div style={{ marginTop: '0.75rem', fontSize: '0.85rem' }} className="mono">
                          {selectedFile?.name} ({(selectedFile ? selectedFile.size / 1024 : 0).toFixed(0)} KB)
                        </div>
                      </div>
                    ) : selectedFile ? (
                      <div>
                        <FileText size={48} className="text-gold" style={{ margin: '0 auto 0.5rem' }} />
                        <div className="mono" style={{ fontSize: '0.9rem' }}>
                          {selectedFile.name}
                        </div>
                        <span className="text-muted text-xs">{(selectedFile.size / 1024).toFixed(0)} KB PDF Document</span>
                      </div>
                    ) : (
                      <div>
                        <Camera size={44} className="text-gold" style={{ margin: '0 auto 0.75rem' }} />
                        <h4 style={{ margin: '0 0 0.25rem' }}>Scan or Select Tax Receipt</h4>
                        <p className="text-muted text-xs" style={{ maxWidth: 360, margin: '0 auto 1.25rem' }}>
                          Supports rear camera capture on iOS/Android, plus JPEG, PNG, WebP, and PDF files up to 10 MB.
                        </p>
                      </div>
                    )}

                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'center',
                        gap: '0.75rem',
                        flexWrap: 'wrap',
                        marginTop: '1rem'
                      }}
                    >
                      <button
                        type="button"
                        className="btn btn-secondary"
                        onClick={() => cameraInputRef.current?.click()}
                      >
                        <Camera size={16} />
                        <span>Take Photo (Camera)</span>
                      </button>

                      <button
                        type="button"
                        className="btn btn-secondary"
                        onClick={() => fileInputRef.current?.click()}
                      >
                        <Upload size={16} />
                        <span>Choose File / PDF</span>
                      </button>
                    </div>
                  </div>

                  {selectedFile && (
                    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
                      <button
                        type="button"
                        className="btn btn-secondary"
                        onClick={resetState}
                        disabled={isProcessing}
                      >
                        <RotateCcw size={14} />
                        <span>Retake / Clear</span>
                      </button>

                      <button
                        type="button"
                        className="btn btn-primary"
                        onClick={handleUploadAndAnalyze}
                        disabled={isProcessing}
                        style={{ gap: '0.5rem' }}
                      >
                        {isProcessing ? (
                          <>
                            <Loader2 size={16} className="animate-spin" />
                            <span>Analyzing with OCR…</span>
                          </>
                        ) : (
                          <>
                            <Sparkles size={16} />
                            <span>Upload & Analyze (OCR)</span>
                            <ArrowRight size={14} />
                          </>
                        )}
                      </button>
                    </div>
                  )}
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
