import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, render, screen, fireEvent, within } from '@testing-library/react';
import CasaCareApp from '../casa-care-app.jsx';

vi.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    rpc: vi.fn().mockResolvedValue({ data: null, error: null }),
    auth: {
      getSession: vi.fn().mockResolvedValue({ data: { session: null } }),
      onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
      signInWithOtp: vi.fn().mockResolvedValue({ error: null }),
      verifyOtp: vi.fn().mockResolvedValue({ data: { user: { id: 'staff-user' } }, error: null }),
      signOut: vi.fn(),
    },
    from: vi.fn(() => ({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
      order: vi.fn().mockResolvedValue({ data: [], error: null }),
      insert: vi.fn().mockResolvedValue({ error: null }),
      update: vi.fn().mockReturnThis(),
      in: vi.fn().mockReturnThis(),
    })),
    storage: {
      from: vi.fn(() => ({
        upload: vi.fn().mockResolvedValue({ error: null }),
      })),
    },
  }),
}));

afterEach(() => {
  cleanup();
});

describe('CasaCareApp staff onboarding UI', () => {
  it('shows professional profile fields after selecting Staff / Professional', async () => {
    render(<CasaCareApp />);

    fireEvent.click(await screen.findByText('Get Started'));
    fireEvent.click(screen.getByText('Staff / Professional'));
    fireEvent.change(screen.getByPlaceholderText('Enter 10-digit number'), {
      target: { value: '9876543210' },
    });
    fireEvent.click(screen.getByText('Send OTP'));
    fireEvent.change(await screen.findByPlaceholderText('000000'), {
      target: { value: '123456' },
    });
    fireEvent.click(screen.getByText('Verify OTP'));

    expect(await screen.findByText('Skills / Category')).toBeInTheDocument();
    expect(screen.getByText('Availability')).toBeInTheDocument();
    expect(screen.getByText('KYC Document (ID proof / Certification)')).toBeInTheDocument();
  });

  it('shows the local walkthrough control in demo mode', async () => {
    render(<CasaCareApp />);

    expect(await screen.findByText('Launch Staff Demo')).toBeInTheDocument();
  });
});
