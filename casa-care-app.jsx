import React, { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';

// Supabase Client (Money will add real env vars when deploying)
const supabaseUrl = process.env.REACT_APP_SUPABASE_URL || 'YOUR_SUPABASE_URL';
const supabaseKey = process.env.REACT_APP_SUPABASE_ANON_KEY || 'YOUR_SUPABASE_KEY';
const supabase = createClient(supabaseUrl, supabaseKey);

export default function CasaCareApp() {
  // Auth & Flow State
  const [authState, setAuthState] = useState('landing'); // landing | tier | phone | otp | profile | dashboard
  const [userTier, setUserTier] = useState(null); // individual | nri | corporate | field_force
  const [phoneNumber, setPhoneNumber] = useState('');
  const [otp, setOtp] = useState('');
  const [profile, setProfile] = useState({
    fullName: '',
    email: '',
    language: 'en',
    address: '',
    city: '',
    zipCode: '',
    kycDoc: null, // for NRI/Corporate
  });
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Check if user is already logged in
  useEffect(() => {
    // 1. Check for existing session on mount
    const checkSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        setCurrentUser(session.user);
        // Fetch user profile from custom table
        const { data: userProfile } = await supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', session.user.id)
          .single();
        if (userProfile) {
          setAuthState('dashboard');
        } else {
          setAuthState('tier');
        }
      }
    };
    
    checkSession();

    // 2. Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session?.user) {
        setCurrentUser(session.user);
        // Fetch user profile from custom table
        const { data: userProfile } = await supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', session.user.id)
          .single();
        if (userProfile) {
          setAuthState('dashboard');
        } else {
          setAuthState('tier');
        }
      } else {
        // Logged out
        setCurrentUser(null);
        setAuthState('landing');
      }
    });

    // 3. Cleanup subscription on unmount
    return () => {
      subscription?.unsubscribe();
    };
  }, []);

  // Step 1: Tier Selection
  const handleTierSelect = (tier) => {
    setUserTier(tier);
    setAuthState('phone');
  };

  // Step 2: Phone Number Submission
  const handlePhoneSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    // Validate Indian phone number
    const cleanPhone = phoneNumber.replace(/\D/g, '');
    if (cleanPhone.length !== 10) {
      setError('Please enter a valid 10-digit Indian phone number');
      setLoading(false);
      return;
    }

    try {
      // Supabase OTP (using phone authentication)
      const { error: signUpError } = await supabase.auth.signInWithOtp({
        phone: `+91${cleanPhone}`,
      });

      if (signUpError) throw signUpError;
      setAuthState('otp');
    } catch (err) {
      setError(err.message || 'Failed to send OTP');
    }
    setLoading(false);
  };

  // Step 3: OTP Verification
  const handleOtpSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const cleanPhone = phoneNumber.replace(/\D/g, '');
      const { data, error: verifyError } = await supabase.auth.verifyOtp({
        phone: `+91${cleanPhone}`,
        token: otp,
        type: 'sms',
      });

      if (verifyError) throw verifyError;

      setCurrentUser(data.user);
      setAuthState('profile');
    } catch (err) {
      setError(err.message || 'Invalid OTP');
    }
    setLoading(false);
  };

  // Step 4: Profile Completion & Account Creation
  const handleProfileSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      if (!profile.fullName || !profile.email || !profile.address) {
        setError('Please fill in all required fields');
        setLoading(false);
        return;
      }

      // Create user profile in Supabase
      const { error: insertError } = await supabase.from('user_profiles').insert({
        user_id: currentUser.id,
        phone: `+91${phoneNumber.replace(/\D/g, '')}`,
        tier: userTier,
        full_name: profile.fullName,
        email: profile.email,
        address: profile.address,
        city: profile.city,
        zip_code: profile.zipCode,
        language: profile.language,
        created_at: new Date(),
      });

      if (insertError) throw insertError;

      setAuthState('dashboard');
    } catch (err) {
      setError(err.message || 'Failed to create account');
    }
    setLoading(false);
  };

  // ============ LANDING PAGE ============
  if (authState === 'landing') {
    return (
      <div style={styles.container}>
        <div style={styles.hero}>
          <div style={styles.logo}>
            <div style={styles.logoMark}>C</div>
            <div>
              <div style={styles.logoName}>Casa Care</div>
              <div style={styles.logoTag}>Home services · Done right</div>
            </div>
          </div>
          <h1 style={styles.heroTitle}>Your home.<br />Our expertise.<br /><em>One tap away.</em></h1>
          <p style={styles.heroSubtitle}>
            Verified technicians, live tracking, transparent pricing — all in one app.
          </p>
          <button
            onClick={() => setAuthState('tier')}
            style={styles.ctaButton}
          >
            Get Started
          </button>
          <p style={styles.footerText}>
            Available for AC, RO, plumbing, carpentry, painting, and more.
          </p>
        </div>
      </div>
    );
  }

  // ============ TIER SELECTION ============
  if (authState === 'tier') {
    return (
      <div style={styles.container}>
        <div style={styles.formCard}>
          <h2 style={styles.formTitle}>Who are you?</h2>
          <p style={styles.formSubtitle}>Select the option that fits you best</p>
          <div style={styles.tierGrid}>
            {[
              { id: 'individual', label: 'Individual', desc: 'Homeowner or tenant' },
              { id: 'nri', label: 'NRI Owner', desc: 'Managing property abroad' },
              { id: 'corporate', label: 'Corporate HQ', desc: 'Office or multiple locations' },
              { id: 'field_force', label: 'Field Force', desc: 'Service partner' },
            ].map((tier) => (
              <button
                key={tier.id}
                onClick={() => handleTierSelect(tier.id)}
                style={{
                  ...styles.tierCard,
                  backgroundColor: userTier === tier.id ? '#0e4c5c' : '#f8f4ed',
                  color: userTier === tier.id ? '#f8f4ed' : '#14110d',
                }}
              >
                <div style={styles.tierLabel}>{tier.label}</div>
                <div style={styles.tierDesc}>{tier.desc}</div>
              </button>
            ))}
          </div>
          {userTier && (
            <button
              onClick={() => setAuthState('phone')}
              style={styles.nextButton}
            >
              Continue
            </button>
          )}
        </div>
      </div>
    );
  }

  // ============ PHONE NUMBER ============
  if (authState === 'phone') {
    return (
      <div style={styles.container}>
        <div style={styles.formCard}>
          <h2 style={styles.formTitle}>Let's verify your number</h2>
          <p style={styles.formSubtitle}>We'll send an OTP via SMS</p>
          <form onSubmit={handlePhoneSubmit} style={styles.form}>
            <div style={styles.formGroup}>
              <label style={styles.label}>Phone Number</label>
              <div style={styles.phoneInputWrapper}>
                <span style={styles.phonePrefix}>+91</span>
                <input
                  type="tel"
                  placeholder="Enter 10-digit number"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value.replace(/\D/g, '').slice(0, 10))}
                  style={styles.input}
                  maxLength="10"
                />
              </div>
            </div>
            {error && <div style={styles.error}>{error}</div>}
            <button
              type="submit"
              disabled={loading || phoneNumber.length !== 10}
              style={{
                ...styles.submitButton,
                opacity: loading || phoneNumber.length !== 10 ? 0.5 : 1,
              }}
            >
              {loading ? 'Sending OTP...' : 'Send OTP'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  // ============ OTP VERIFICATION ============
  if (authState === 'otp') {
    return (
      <div style={styles.container}>
        <div style={styles.formCard}>
          <h2 style={styles.formTitle}>Enter your OTP</h2>
          <p style={styles.formSubtitle}>Check your SMS for the 6-digit code</p>
          <form onSubmit={handleOtpSubmit} style={styles.form}>
            <div style={styles.formGroup}>
              <label style={styles.label}>One-Time Password</label>
              <input
                type="text"
                placeholder="000000"
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                style={{
                  ...styles.input,
                  fontSize: '32px',
                  letterSpacing: '8px',
                  textAlign: 'center',
                  fontWeight: '600',
                }}
                maxLength="6"
              />
            </div>
            {error && <div style={styles.error}>{error}</div>}
            <button
              type="submit"
              disabled={loading || otp.length !== 6}
              style={{
                ...styles.submitButton,
                opacity: loading || otp.length !== 6 ? 0.5 : 1,
              }}
            >
              {loading ? 'Verifying...' : 'Verify OTP'}
            </button>
            <button
              type="button"
              onClick={() => setAuthState('phone')}
              style={styles.backButton}
            >
              Back to phone number
            </button>
          </form>
        </div>
      </div>
    );
  }

  // ============ PROFILE COMPLETION ============
  if (authState === 'profile') {
    return (
      <div style={styles.container}>
        <div style={styles.formCard}>
          <h2 style={styles.formTitle}>Complete your profile</h2>
          <p style={styles.formSubtitle}>A few more details to get you started</p>
          <form onSubmit={handleProfileSubmit} style={styles.form}>
            <div style={styles.formGroup}>
              <label style={styles.label}>Full Name *</label>
              <input
                type="text"
                placeholder="Your full name"
                value={profile.fullName}
                onChange={(e) => setProfile({ ...profile, fullName: e.target.value })}
                style={styles.input}
              />
            </div>
            <div style={styles.formGroup}>
              <label style={styles.label}>Email *</label>
              <input
                type="email"
                placeholder="your@email.com"
                value={profile.email}
                onChange={(e) => setProfile({ ...profile, email: e.target.value })}
                style={styles.input}
              />
            </div>
            <div style={styles.formGroup}>
              <label style={styles.label}>Preferred Language</label>
              <select
                value={profile.language}
                onChange={(e) => setProfile({ ...profile, language: e.target.value })}
                style={styles.input}
              >
                <option value="en">English</option>
                <option value="hi">हिन्दी</option>
                <option value="ta">தமிழ்</option>
                <option value="te">తెలుగు</option>
                <option value="kn">ಕನ್ನಡ</option>
                <option value="ml">മലയാളം</option>
              </select>
            </div>
            <div style={styles.formGroup}>
              <label style={styles.label}>Primary Address *</label>
              <input
                type="text"
                placeholder="House No., Street"
                value={profile.address}
                onChange={(e) => setProfile({ ...profile, address: e.target.value })}
                style={styles.input}
              />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={styles.formGroup}>
                <label style={styles.label}>City</label>
                <input
                  type="text"
                  placeholder="City"
                  value={profile.city}
                  onChange={(e) => setProfile({ ...profile, city: e.target.value })}
                  style={styles.input}
                />
              </div>
              <div style={styles.formGroup}>
                <label style={styles.label}>PIN Code</label>
                <input
                  type="text"
                  placeholder="110001"
                  value={profile.zipCode}
                  onChange={(e) => setProfile({ ...profile, zipCode: e.target.value })}
                  style={styles.input}
                />
              </div>
            </div>
            {userTier === 'nri' && (
              <div style={styles.formGroup}>
                <label style={styles.label}>KYC Document (Passport / OCI)</label>
                <input
                  type="file"
                  accept="image/*, .pdf"
                  onChange={(e) => setProfile({ ...profile, kycDoc: e.target.files?.[0] })}
                  style={styles.input}
                />
              </div>
            )}
            {error && <div style={styles.error}>{error}</div>}
            <button
              type="submit"
              disabled={loading}
              style={{
                ...styles.submitButton,
                opacity: loading ? 0.5 : 1,
              }}
            >
              {loading ? 'Creating Account...' : 'Create Account'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  // ============ DASHBOARD ============
  if (authState === 'dashboard' && currentUser) {
    return (
      <div style={styles.container}>
        <div style={styles.dashboard}>
          <div style={styles.dashboardHeader}>
            <div style={styles.logo}>
              <div style={styles.logoMark}>C</div>
              <div>
                <div style={styles.logoName}>Casa Care</div>
              </div>
            </div>
            <button
              onClick={() => {
                supabase.auth.signOut();
                setAuthState('landing');
                setCurrentUser(null);
              }}
              style={styles.logoutButton}
            >
              Sign Out
            </button>
          </div>

          <div style={styles.welcomeSection}>
            <h2 style={styles.dashboardTitle}>Welcome back!</h2>
            <p style={styles.dashboardSubtitle}>Your account is active and ready to book services.</p>
          </div>

          <div style={styles.cardGrid}>
            <div style={styles.card}>
              <div style={styles.cardIcon}>📝</div>
              <div style={styles.cardTitle}>Book a Service</div>
              <p style={styles.cardDesc}>AC, RO, plumbing, carpentry, painting & more</p>
              <button style={styles.cardButton}>Browse Services</button>
            </div>
            <div style={styles.card}>
              <div style={styles.cardIcon}>📱</div>
              <div style={styles.cardTitle}>Track Orders</div>
              <p style={styles.cardDesc}>Live tracking of your service requests</p>
              <button style={styles.cardButton}>View Active Jobs</button>
            </div>
            <div style={styles.card}>
              <div style={styles.cardIcon}>⭐</div>
              <div style={styles.cardTitle}>Your Assets</div>
              <p style={styles.cardDesc}>Scan QR to see service history</p>
              <button style={styles.cardButton}>View Assets</button>
            </div>
            <div style={styles.card}>
              <div style={styles.cardIcon}>📊</div>
              <div style={styles.cardTitle}>Wallet & History</div>
              <p style={styles.cardDesc}>Invoices, payments & spending</p>
              <button style={styles.cardButton}>View History</button>
            </div>
          </div>

          <div style={styles.infoBox}>
            <div style={styles.infoBadge}>ℹ️ You're all set</div>
            <p style={styles.infoText}>
              Your account is verified and ready. Book your first service now to get started with Casa Care's verified technicians and transparent pricing.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

// ============ STYLES ============
const styles = {
  container: {
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #f8f4ed 0%, #f0e9dc 100%)',
    padding: '16px',
    fontFamily: '"IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    color: '#14110d',
  },
  hero: {
    maxWidth: '600px',
    margin: '0 auto',
    paddingTop: '48px',
    paddingBottom: '48px',
    textAlign: 'center',
  },
  logo: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '12px',
    marginBottom: '40px',
  },
  logoMark: {
    width: '54px',
    height: '54px',
    background: '#0e4c5c',
    color: '#f8f4ed',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '28px',
    fontWeight: '600',
    fontStyle: 'italic',
    borderRadius: '4px',
    border: '2px solid #14110d',
  },
  logoName: {
    fontSize: '22px',
    fontWeight: '600',
    fontFamily: '"Fraunces", serif',
  },
  logoTag: {
    fontSize: '11px',
    color: '#6b6357',
    letterSpacing: '0.1em',
    textTransform: 'uppercase',
    marginTop: '4px',
  },
  heroTitle: {
    fontSize: 'clamp(32px, 8vw, 56px)',
    fontFamily: '"Fraunces", serif',
    fontWeight: '400',
    lineHeight: '1.1',
    marginBottom: '24px',
    letterSpacing: '-0.02em',
  },
  heroTitleEm: {
    fontStyle: 'italic',
    color: '#b6502b',
  },
  heroSubtitle: {
    fontSize: '16px',
    color: '#2a2620',
    lineHeight: '1.6',
    marginBottom: '32px',
    maxWidth: '480px',
    margin: '0 auto 32px',
  },
  ctaButton: {
    background: '#0e4c5c',
    color: '#f8f4ed',
    border: 'none',
    padding: '16px 40px',
    fontSize: '16px',
    fontWeight: '600',
    borderRadius: '4px',
    cursor: 'pointer',
    marginBottom: '24px',
    transition: 'background 0.2s',
  },
  footerText: {
    fontSize: '13px',
    color: '#6b6357',
    margin: '0',
  },
  formCard: {
    maxWidth: '500px',
    margin: '48px auto',
    background: '#ffffff',
    padding: '32px 24px',
    borderRadius: '8px',
    border: '1px solid #e8dfce',
    boxShadow: '0 2px 8px rgba(20,17,13,0.08)',
  },
  formTitle: {
    fontSize: '28px',
    fontFamily: '"Fraunces", serif',
    fontWeight: '500',
    margin: '0 0 8px',
    letterSpacing: '-0.01em',
  },
  formSubtitle: {
    fontSize: '14px',
    color: '#6b6357',
    margin: '0 0 24px',
    lineHeight: '1.5',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  formGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  label: {
    fontSize: '13px',
    fontWeight: '600',
    color: '#14110d',
    letterSpacing: '0.05em',
  },
  input: {
    padding: '12px 14px',
    fontSize: '15px',
    border: '1px solid #d9cdc0',
    borderRadius: '4px',
    fontFamily: 'inherit',
    transition: 'border-color 0.2s',
  },
  phoneInputWrapper: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  phonePrefix: {
    fontSize: '16px',
    fontWeight: '600',
    color: '#14110d',
  },
  tierGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '12px',
    marginBottom: '24px',
  },
  tierCard: {
    padding: '16px 12px',
    border: '2px solid #14110d',
    borderRadius: '4px',
    cursor: 'pointer',
    textAlign: 'center',
    transition: 'all 0.2s',
    fontSize: '13px',
    fontWeight: '500',
    fontFamily: 'inherit',
  },
  tierLabel: {
    fontSize: '15px',
    fontWeight: '600',
    marginBottom: '4px',
  },
  tierDesc: {
    fontSize: '12px',
    opacity: 0.7,
  },
  submitButton: {
    background: '#0e4c5c',
    color: '#f8f4ed',
    border: 'none',
    padding: '14px 16px',
    fontSize: '15px',
    fontWeight: '600',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'background 0.2s',
  },
  nextButton: {
    background: '#0e4c5c',
    color: '#f8f4ed',
    border: 'none',
    padding: '14px 16px',
    fontSize: '15px',
    fontWeight: '600',
    borderRadius: '4px',
    cursor: 'pointer',
    marginTop: '8px',
  },
  backButton: {
    background: 'transparent',
    color: '#0e4c5c',
    border: '1px solid #0e4c5c',
    padding: '12px 16px',
    fontSize: '14px',
    fontWeight: '500',
    borderRadius: '4px',
    cursor: 'pointer',
    marginTop: '8px',
  },
  error: {
    color: '#a03021',
    fontSize: '13px',
    padding: '10px',
    background: '#fae8e3',
    borderRadius: '4px',
    border: '1px solid #f0d4c8',
  },
  dashboard: {
    maxWidth: '1000px',
    margin: '0 auto',
    paddingTop: '24px',
    paddingBottom: '64px',
  },
  dashboardHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '48px',
    paddingBottom: '20px',
    borderBottom: '1px solid #e8dfce',
  },
  welcomeSection: {
    marginBottom: '40px',
  },
  dashboardTitle: {
    fontSize: '32px',
    fontFamily: '"Fraunces", serif',
    fontWeight: '500',
    margin: '0 0 8px',
  },
  dashboardSubtitle: {
    fontSize: '16px',
    color: '#2a2620',
    margin: '0',
    lineHeight: '1.5',
  },
  cardGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
    gap: '16px',
    marginBottom: '40px',
  },
  card: {
    background: '#ffffff',
    padding: '20px',
    borderRadius: '6px',
    border: '1px solid #e8dfce',
    textAlign: 'center',
  },
  cardIcon: {
    fontSize: '32px',
    marginBottom: '12px',
  },
  cardTitle: {
    fontSize: '16px',
    fontWeight: '600',
    margin: '0 0 6px',
  },
  cardDesc: {
    fontSize: '13px',
    color: '#6b6357',
    margin: '0 0 12px',
    lineHeight: '1.5',
  },
  cardButton: {
    background: '#f0e9dc',
    border: '1px solid #d9cdc0',
    padding: '8px 12px',
    fontSize: '12px',
    fontWeight: '600',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'background 0.2s',
  },
  infoBox: {
    background: '#e1eaec',
    border: '1px solid #0e4c5c',
    borderLeft: '4px solid #0e4c5c',
    padding: '16px',
    borderRadius: '4px',
  },
  infoBadge: {
    fontSize: '12px',
    fontWeight: '600',
    color: '#0e4c5c',
    marginBottom: '6px',
    textTransform: 'uppercase',
    letterSpacing: '0.05em',
  },
  infoText: {
    fontSize: '14px',
    color: '#2a2620',
    margin: '0',
    lineHeight: '1.55',
  },
  logoutButton: {
    background: 'transparent',
    border: '1px solid #d9cdc0',
    padding: '8px 16px',
    fontSize: '13px',
    fontWeight: '600',
    borderRadius: '4px',
    cursor: 'pointer',
    color: '#14110d',
  },
};
