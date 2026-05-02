import { readdirSync, readFileSync } from 'node:fs';
import { basename, join, relative } from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = new URL('..', import.meta.url).pathname;
const app = readFileSync(join(root, 'casa-care-app.jsx'), 'utf8');
const schema = readFileSync(join(root, 'supabase/migrations/001_casa_care_schema.sql'), 'utf8');

const listFiles = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '.git' || entry.name === 'node_modules') return [];
    const fullPath = join(dir, entry.name);
    return entry.isDirectory() ? listFiles(fullPath) : fullPath;
  });

test('schema uses Postgres-safe ticket ids and exposes pending jobs for staff claims', () => {
  assert.doesNotMatch(schema, /DATE_FORMAT|RAND\(|AS CHAR/i);
  assert.match(schema, /CREATE TYPE user_role AS ENUM \('customer', 'staff'\)/);
  assert.match(schema, /CREATE TYPE ticket_status AS ENUM \('pending', 'assigned'/);
  assert.match(schema, /assigned_to UUID REFERENCES user_profiles\(user_id\)/);
  assert.match(schema, /CREATE INDEX idx_service_requests_pending_jobs ON service_requests\(status, created_at\)/);
});

test('schema lets authenticated users insert profiles and staff claim pending jobs', () => {
  assert.match(schema, /CREATE POLICY "Users insert own profile" ON user_profiles\s+FOR INSERT WITH CHECK \(\s+auth\.uid\(\) = user_id/);
  assert.match(schema, /CREATE POLICY "Staff view pending requests" ON service_requests/);
  assert.match(schema, /CREATE OR REPLACE FUNCTION claim_service_request/);
  assert.match(schema, /SECURITY DEFINER/);
  assert.doesNotMatch(schema, /CREATE POLICY "Staff claim pending requests"/);
  assert.doesNotMatch(schema, /GRANT UPDATE \(status, assigned_to, updated_at\)/);
  assert.match(schema, /REVOKE UPDATE ON service_requests FROM authenticated/);
  assert.match(schema, /status = 'pending'/);
  assert.match(schema, /role = 'staff'[\s\S]*kyc_verified IS TRUE/);
  assert.match(schema, /assigned_to = requester/);
  assert.match(schema, /NEW\.role = OLD\.role/);
});

test('signup differentiates customers from staff and requires staff KYC persistence', () => {
  assert.match(app, /I need a service/);
  assert.match(app, /I am a Professional \(Staff\)/);
  assert.match(app, /role: signupRole/);
  assert.match(app, /signupRole === 'staff'/);
  assert.match(app, /kycDoc/);
  assert.match(app, /kyc_doc_url/);
  assert.match(app, /\.storage[\s\S]*\.from\('kyc-documents'\)[\s\S]*\.upload\(/);
});

test('staff dashboard hides booking UI and provides claiming, active jobs, and wallet sections', () => {
  assert.match(app, /isStaff/);
  assert.match(app, /Available Gigs/);
  assert.match(app, /Claim Job/);
  assert.match(app, /Active Jobs/);
  assert.match(app, /Wallet/);
  assert.match(app, /handleClaimJob/);
  assert.match(app, /\.rpc\('claim_service_request'/);
  assert.match(app, /\.from\('service_requests'\)[\s\S]*\.eq\('status', 'pending'\)/);
  assert.match(app, /already claimed/);
});

test('CasaCare implementation has one canonical app file', () => {
  const casaFiles = listFiles(root)
    .filter((file) => /casa[-_]?care.*\.(jsx|tsx|js|ts)$/i.test(basename(file)))
    .map((file) => relative(root, file));

  assert.deepEqual(casaFiles, ['casa-care-app.jsx']);
});
