# 🔐 Casa Care Autopilot — Secrets Checklist

## Quick Setup (5 Minutes)

### What You Need to Create

1. **Supabase Access Token**
   - Go to: https://supabase.com/dashboard/account/tokens
   - Click "Create new token"
   - Label: `casa-care-autopilot`
   - Copy the token

2. **Production Database Password**
   - Go to: https://supabase.com/dashboard/projects/tmiapgccvjdhsflcvotg
   - Click "Settings" (bottom left)
   - Click "Database"
   - Look for "Database password"
   - Copy the password

3. **Production Project ID** (already have)
   - Value: `tmiapgccvjdhsflcvotg`

### Add to GitHub Actions Secrets

**Go to:** https://github.com/karanmanisharma-oss/casa-care/settings/secrets/actions

**Click "New repository secret" and add each:**

```
Name: SUPABASE_ACCESS_TOKEN
Value: [paste from Supabase tokens page]
```

```
Name: PRODUCTION_PROJECT_ID
Value: tmiapgccvjdhsflcvotg
```

```
Name: PRODUCTION_DB_PASSWORD
Value: [paste from Supabase database settings]
```

### Verify

Go to: https://github.com/karanmanisharma-oss/casa-care/settings/secrets/actions

You should see all 3 secrets listed:
- ✅ SUPABASE_ACCESS_TOKEN
- ✅ PRODUCTION_PROJECT_ID
- ✅ PRODUCTION_DB_PASSWORD

## Done ✅

Your autopilot is now configured and ready for Claude to use.
