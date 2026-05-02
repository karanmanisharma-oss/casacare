import { describe, expect, it } from 'vitest';
import {
  buildKycStoragePath,
  buildProfilePayload,
  getDashboardView,
  isProfessionalTier,
} from './casaCareLogic';

describe('CasaCare role workflow helpers', () => {
  it('routes staff professionals to the staff dashboard', () => {
    expect(getDashboardView({ tier: 'staff_professional' })).toBe('staff');
    expect(getDashboardView({ tier: 'field_force' })).toBe('staff');
    expect(getDashboardView({ tier: 'nri' })).toBe('customer');
  });

  it('identifies the staff/professional tiers', () => {
    expect(isProfessionalTier('staff_professional')).toBe(true);
    expect(isProfessionalTier('field_force')).toBe(true);
    expect(isProfessionalTier('corporate')).toBe(false);
  });

  it('builds a profile payload with professional metadata', () => {
    expect(
      buildProfilePayload({
        currentUser: { id: 'user-123' },
        phoneNumber: '98765 43210',
        userTier: 'staff_professional',
        profile: {
          fullName: 'Asha Rao',
          email: 'asha@example.com',
          address: '12 MG Road',
          city: 'Bengaluru',
          zipCode: '560001',
          language: 'en',
          skills: ['ac', 'plumbing'],
          availability: 'available',
        },
        kycPath: 'user-123/kyc.pdf',
      }),
    ).toMatchObject({
      user_id: 'user-123',
      phone: '+919876543210',
      tier: 'staff_professional',
      skills: ['ac', 'plumbing'],
      verification_status: 'submitted',
      availability: 'available',
      kyc_doc_url: 'user-123/kyc.pdf',
    });
  });

  it('uses a user-scoped KYC storage path', () => {
    expect(buildKycStoragePath('user-123', { name: 'ID Proof.PDF' })).toMatch(
      /^user-123\/kyc-\d+-id-proof\.pdf$/,
    );
  });
});
