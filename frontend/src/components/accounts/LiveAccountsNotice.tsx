import React from 'react';
import { AlertTriangle, Clock, Database, Loader2 } from 'lucide-react';
import { LiveAccountsState } from '../../services/liveData';

interface LiveAccountsNoticeProps {
  live: LiveAccountsState;
}

/**
 * Explains the provenance of account data shown under the "Google Sheets Live" badge.
 * Renders nothing when fresh live records are displayed.
 */
export const LiveAccountsNotice: React.FC<LiveAccountsNoticeProps> = ({ live }) => {
  if (live.status === 'ready') return null;

  const verified = live.verifiedAt ? new Date(live.verifiedAt).toLocaleString() : null;

  let tone = 'live-notice-info';
  let icon = <Database size={16} />;
  let message: string;

  switch (live.status) {
    case 'loading':
      icon = <Loader2 size={16} />;
      message = 'Loading accounts from the live database…';
      break;
    case 'empty':
      message = 'The live database returned no accounts. Balances will appear here once accounts are added.';
      break;
    case 'stale':
      tone = 'live-notice-warn';
      icon = <Clock size={16} />;
      message = `Showing stale live data last verified ${verified}. The latest refresh failed${live.error ? `: ${live.error}` : '.'}`;
      break;
    case 'unavailable':
    default:
      tone = 'live-notice-error';
      icon = <AlertTriangle size={16} />;
      message = `Live accounts are unavailable${live.error ? `: ${live.error}` : '.'} No balances are shown until the database responds.`;
      break;
  }

  return (
    <div className={`glass-panel live-notice ${tone}`} role="status" id={`live-accounts-${live.status}`}>
      {icon}
      <span>{message}</span>
    </div>
  );
};
