# 🚀 Casa Care Autopilot Setup

## ✅ Repo Created with Autopilot Workflows

Your `casa-care` repository is now ready with automated deployment pipelines.

## 📁 What's Included

- ✅ `.github/workflows/ci.yml` — Runs CI checks on all PRs to main
- ✅ `.github/workflows/production-db.yml` — Auto-deploys Supabase migrations on merge to main
- ✅ `supabase/migrations/` — Folder for your migration files
- ✅ `SECRETS_CHECKLIST.md` — Quick reference for secrets setup

## 🎯 Setup in 5 Minutes

### Step 1: Create GitHub Secrets

**Go to:** https://github.com/karanmanisharma-oss/casacare/settings/secrets/actions

**Click "New repository secret" and add these 3 secrets:**

| Secret Name | Value | Where to Find |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | Your Supabase personal access token | https://supabase.com/dashboard/account/tokens |
| `PRODUCTION_PROJECT_ID` | `tmiapgccvjdhsflcvotg` | (already provided) |
| `PRODUCTION_DB_PASSWORD` | Your production database password | Supabase Dashboard > Project > Settings > Database > Password |

### Step 2: Verify Workflows

**Go to:** https://github.com/karanmanisharma-oss/casacare/actions

You should see:
- ✅ `CI` workflow
- ✅ `Production DB Deploy` workflow

### Step 3: Test with First Migration

1. Create a file: `supabase/migrations/001_init.sql`
2. Add test SQL (e.g., `CREATE TABLE users (id SERIAL PRIMARY KEY);`)
3. Commit and push to main
4. **Production DB Deploy** should auto-run
5. Check Actions tab to confirm deployment succeeded

### Step 4: Create Branch Protection (Recommended)

**Go to:** https://github.com/karanmanisharma-oss/casacare/settings/branches

- Click "Add rule"
- Branch name: `main`
- Enable: "Require a pull request before merging"
- Enable: "Require status checks to pass before merging"
- Select: `sanity` (from CI workflow)
- Save

## 🤖 Claude Autopilot Ready

Once secrets are added, Claude can:
- ✅ Write database migrations automatically
- ✅ Commit changes to main
- ✅ Deploy to production (Supabase)
- ✅ Deploy to Vercel
- ✅ Handle rollbacks with your approval
- ✅ **Never ask you to deploy again**

## 📚 How It Works

### CI Workflow
- **Trigger:** Pull request to `main`
- **Action:** Runs sanity checks
- **Purpose:** Prevent broken code from merging

### Production DB Deploy Workflow
- **Trigger:** Push to `main` with changes in `supabase/migrations/**`
- **Action:** Runs `supabase db push` automatically
- **Purpose:** Deploy database migrations instantly

## 🔧 Future Additions (Phase 2)

When you're ready, we can add:
- Edge Functions deployment (when needed)
- Vercel auto-deployments
- Staging environment workflows
- Automated rollback workflows

## 🆘 Troubleshooting

### Workflow fails: "Link to Production Project"
- Check `SUPABASE_ACCESS_TOKEN` is correct
- Verify it has required permissions

### Workflow fails: "Push Migrations to Production"
- Ensure `supabase/migrations/` folder exists
- Check migration files are valid SQL
- Verify `PRODUCTION_DB_PASSWORD` is correct

### Secrets not showing in Actions
- Refresh the page
- Ensure you added them to "Actions secrets", not "Dependabot secrets"

## 📞 Next Steps

1. ✅ Add the 3 secrets to GitHub Actions
2. ✅ Create first test migration
3. ✅ Push and watch auto-deployment
4. ✅ Tell Claude autopilot is ready
5. ✅ Claude takes over deployment tasks

---

**Status:** Autopilot workflows ready ✅
