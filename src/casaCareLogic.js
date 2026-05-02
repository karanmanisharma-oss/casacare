export const PROFESSIONAL_TIER = 'staff_professional';

export const SERVICE_CATEGORIES = [
  { id: 'ac', label: 'AC Service' },
  { id: 'ro', label: 'RO Service' },
  { id: 'plumbing', label: 'Plumbing' },
  { id: 'carpentry', label: 'Carpentry' },
  { id: 'painting', label: 'Painting' },
  { id: 'nri_property', label: 'NRI Property Care' },
  { id: 'movers', label: 'Movers' },
  { id: 'amc', label: 'AMC' },
];

export function isProfessionalTier(tier) {
  return tier === PROFESSIONAL_TIER || tier === 'field_force';
}

export function getDashboardView(userProfile) {
  return isProfessionalTier(userProfile?.tier) ? 'staff' : 'customer';
}

export function buildKycStoragePath(userId, file) {
  if (!userId) {
    throw new Error('User ID is required before uploading KYC documents.');
  }

  if (!file?.name) {
    throw new Error('A KYC document file is required.');
  }

  const parts = file.name.split('.');
  const extension = parts.length > 1 ? parts.pop().toLowerCase() : 'bin';
  const baseName = parts
    .join('.')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
  const timestamp = Date.now();
  return `${userId}/kyc-${timestamp}-${baseName || 'document'}.${extension}`;
}

export function buildProfilePayload({
  profile,
  userId,
  currentUser,
  phoneNumber,
  userTier,
  kycDocPath,
  kycPath,
}) {
  const cleanPhone = phoneNumber.replace(/\D/g, '');
  const skills = isProfessionalTier(userTier) ? profile.skills : [];
  const documentPath = kycDocPath ?? kycPath;

  return {
    user_id: userId ?? currentUser?.id,
    phone: `+91${cleanPhone}`,
    tier: userTier,
    full_name: profile.fullName.trim(),
    email: profile.email.trim(),
    address: profile.address.trim(),
    city: profile.city.trim(),
    zip_code: profile.zipCode.trim(),
    language: profile.language,
    kyc_doc_url: documentPath,
    skills,
    verification_status: documentPath ? 'submitted' : 'pending',
    availability: isProfessionalTier(userTier) ? profile.availability : 'offline',
    updated_at: new Date().toISOString(),
  };
}
