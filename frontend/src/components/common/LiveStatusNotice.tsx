import React from 'react';
import { AlertTriangle, Clock, Database, Loader2 } from 'lucide-react';
import type { LiveDataStatus } from '../../services/liveData';

interface LiveStatusNoticeProps {
  status: LiveDataStatus;
  verifiedAt?: string | null;
  error?: string | null;
  entityName: string;
  emptyMessage?: string;
  idPrefix?: string;
}

/**
 * Universal notice banner explaining the provenance of live Google Sheets data.
 * Displays loading, empty, stale, or unavailable states.
 * Renders nothing when fresh live records ('ready') are present.
 */
export const LiveStatusNotice: React.FC<LiveStatusNoticeProps> = ({
  status,
  verifiedAt,
  error,
  entityName,
  emptyMessage,
  idPrefix = 'live-status'
}) => {
  if (status === 'ready') return null;

  const verified = verifiedAt ? new Date(verifiedAt).toLocaleString() : null;

  let tone = 'live-notice-info';
  let icon = <Database size={16} />;
  let message: string;

  switch (status) {
    case 'loading':
      icon = <Loader2 size={16} className="animate-spin" />;
      message = `Loading ${entityName} from Google Sheets…`;
      break;
    case 'empty':
      message = emptyMessage || `The live database returned no ${entityName}. Records will appear here once added in Google Sheets.`;
      break;
    case 'stale':
      tone = 'live-notice-warn';
      icon = <Clock size={16} />;
      message = `Showing stale live ${entityName} last verified ${verified}. The latest refresh failed${error ? `: ${error}` : '.'}`;
      break;
    case 'unavailable':
    default:
      tone = 'live-notice-error';
      icon = <AlertTriangle size={16} />;
      message = `Live ${entityName} are unavailable${error ? `: ${error}` : '.'} No data is shown until the database responds.`;
      break;
  }

  return (
    <div className={`glass-panel live-notice ${tone}`} role="status" id={`${idPrefix}-${status}`}>
      {icon}
      <span>{message}</span>
    </div>
  );
};
