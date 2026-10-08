import React, { useState, useEffect } from 'react';
import { Lock, Fingerprint, ShieldAlert, Sparkles, AlertTriangle, CheckCircle2, ArrowRight } from 'lucide-react';
import { startAuthentication, browserSupportsWebAuthn } from '@simplewebauthn/browser';
import { financeApi, UserSession } from '../../services/api';

declare global {
  interface Window {
    google?: any;
  }
}

interface AuthModalProps {
  isOpen: boolean;
  onSuccess: (session: UserSession) => void;
  onSwitchToDemo: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onSuccess, onSwitchToDemo }) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [webAuthnSupported, setWebAuthnSupported] = useState(false);
  const [googleClientReady, setGoogleClientReady] = useState(false);

  useEffect(() => {
    setWebAuthnSupported(browserSupportsWebAuthn());

    // Dynamically load Google Identity Services SDK if not already present
    if (typeof window !== 'undefined' && !window.google?.accounts) {
      const script = document.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      script.defer = true;
      script.onload = () => {
        setGoogleClientReady(true);
      };
      document.head.appendChild(script);
    } else {
      setGoogleClientReady(true);
    }
  }, []);

  // Initialize Google Sign-in button when Google client and modal are ready
  useEffect(() => {
    if (!isOpen || !googleClientReady || !window.google?.accounts?.id) return;

    try {
      const googleClientId =
        import.meta.env.VITE_GOOGLE_CLIENT_ID ||
        '734892749281-placeholder.apps.googleusercontent.com'; // User replaces in env

      window.google.accounts.id.initialize({
        client_id: googleClientId,
        callback: async (response: { credential: string }) => {
          if (!response.credential) return;
          setLoading(true);
          setError(null);
          try {
            const session = await financeApi.loginWithGoogle(response.credential);
            onSuccess(session);
          } catch (err: any) {
            setError(err.message || 'Google authentication failed');
          } finally {
            setLoading(false);
          }
        }
      });

      const btnContainer = document.getElementById('google-signin-btn-container');
      if (btnContainer) {
        btnContainer.innerHTML = '';
        window.google.accounts.id.renderButton(btnContainer, {
          theme: 'filled_black',
          size: 'large',
          shape: 'pill',
          text: 'signin_with',
          width: 280
        });
      }
    } catch (err) {
      console.warn('Could not initialize Google Sign-In button:', err);
    }
  }, [isOpen, googleClientReady]);

  if (!isOpen) return null;

  const handlePasskeySignIn = async () => {
    setLoading(true);
    setError(null);
    try {
      // 1. Get WebAuthn options from backend
      const options = await financeApi.getPasskeyLoginOptions();

      // 2. Start browser WebAuthn authentication (prompts Face ID / Touch ID / Passkey)
      const authResp = await startAuthentication({ optionsJSON: options });

      // 3. Verify assertion with backend
      const session = await financeApi.verifyPasskeyLogin(authResp);
      onSuccess(session);
    } catch (err: any) {
      if (err.name === 'NotAllowedError') {
        setError('Passkey prompt was canceled or timed out.');
      } else {
        setError(err.message || 'Passkey authentication failed. Please use Google Sign-in or check setup.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop animate-fade-in" style={{ zIndex: 1100 }}>
      <div className="glass-panel modal-card auth-modal-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 440 }}>
        <div className="modal-header" style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.08)', paddingBottom: '1rem' }}>
          <div className="modal-title-wrap">
            <div className="brand-logo-gem" style={{ width: 34, height: 34 }}>
              <Lock size={18} className="text-gold" />
            </div>
            <div>
              <h3 style={{ fontSize: '1.15rem', margin: 0 }}>Owner Authentication</h3>
              <span className="text-xs text-muted">Ziva Private Financial Command Center</span>
            </div>
          </div>
        </div>

        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem', paddingTop: '1.25rem' }}>
          <div className="auth-notice-banner" style={{
            background: 'rgba(217, 119, 6, 0.12)',
            border: '1px solid rgba(217, 119, 6, 0.3)',
            borderRadius: '8px',
            padding: '0.85rem',
            fontSize: '0.825rem',
            lineHeight: 1.45,
            color: '#fef3c7'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem', fontWeight: 600 }}>
              <ShieldAlert size={16} className="text-gold" />
              <span>Restricted Access Notice</span>
            </div>
            <span>
              Google Sheets Live data and financial ledgers are restricted strictly to the verified owner account. All unauthenticated requests are blocked.
            </span>
          </div>

          {error && (
            <div className="auth-error-banner" style={{
              background: 'rgba(239, 68, 68, 0.15)',
              border: '1px solid rgba(239, 68, 68, 0.4)',
              borderRadius: '8px',
              padding: '0.75rem',
              color: '#fca5a5',
              fontSize: '0.82rem',
              display: 'flex',
              alignItems: 'flex-start',
              gap: '0.5rem'
            }}>
              <AlertTriangle size={16} style={{ flexShrink: 0, marginTop: 2 }} />
              <div>{error}</div>
            </div>
          )}

          {/* Primary Action 1: WebAuthn Passkey (Face ID / Touch ID) */}
          {webAuthnSupported && (
            <button
              type="button"
              className="btn btn-primary"
              onClick={handlePasskeySignIn}
              disabled={loading}
              style={{
                width: '100%',
                justifyContent: 'center',
                padding: '0.75rem 1rem',
                fontSize: '0.95rem',
                gap: '0.65rem'
              }}
            >
              <Fingerprint size={20} />
              <span>{loading ? 'Authenticating…' : 'Sign In with Passkey (Face ID)'}</span>
            </button>
          )}

          {/* Primary Action 2: Google Sign-In */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '0.5rem' }}>
            <div id="google-signin-btn-container" style={{ minHeight: 44 }} />
            <span className="text-xs text-muted">Requires configured owner Google account</span>
          </div>

          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
            margin: '0.25rem 0',
            color: 'rgba(255, 255, 255, 0.3)',
            fontSize: '0.75rem'
          }}>
            <div style={{ flex: 1, height: 1, background: 'rgba(255, 255, 255, 0.1)' }} />
            <span>OR</span>
            <div style={{ flex: 1, height: 1, background: 'rgba(255, 255, 255, 0.1)' }} />
          </div>

          {/* Demo Sandbox Fallback */}
          <button
            type="button"
            className="btn btn-secondary"
            onClick={onSwitchToDemo}
            disabled={loading}
            style={{
              width: '100%',
              justifyContent: 'center',
              padding: '0.65rem',
              fontSize: '0.875rem',
              gap: '0.5rem'
            }}
          >
            <span>Explore Demo Sandbox Mode</span>
            <ArrowRight size={14} />
          </button>
        </div>
      </div>
    </div>
  );
};
