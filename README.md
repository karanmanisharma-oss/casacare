# Casa Care

Automated deployment pipeline for Casa Care with GitHub Actions + Supabase + Vercel.

## Quick Start

1. **Add GitHub Secrets** (see `SECRETS_CHECKLIST.md`)
2. **Create migrations** in `supabase/migrations/`
3. **Push to main** → auto-deployment

## Autopilot Workflows

- **CI** — Runs on every PR to main
- **Production DB Deploy** — Auto-deploys migrations on merge to main

## Documentation

- `AUTOPILOT_SETUP.md` — Complete setup guide
- `SECRETS_CHECKLIST.md` — Quick secrets reference

## Project Structure

```
casa-care/
├── .github/workflows/       # GitHub Actions workflows
│   ├── ci.yml               # CI checks
│   └── production-db.yml    # Auto-deploy migrations
├── supabase/
│   └── migrations/          # Database migrations
└── README.md
```

## Learn More

- [Supabase Docs](https://supabase.com/docs)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Vercel Deployment](https://vercel.com/docs)
