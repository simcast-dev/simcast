# Supabase One-Click Deploy via setup.sh

**Date:** 2026-03-26
**Status:** Approved

## Goal

Make `setup.sh` fully automated for Supabase — the user never visits the Supabase dashboard. The script handles login, project creation, and credential extraction.

## Current State

`setup.sh` requires the user to manually create a Supabase project at supabase.com/dashboard, then copy-paste project ref, URL, and anon key into the script prompts.

## Design

### Login Flow (new step, after prerequisites)

1. Run `supabase projects list` silently as a login check
2. If not logged in, display message and run `supabase login` (browser OAuth)
3. Verify login succeeded before continuing

### Project Creation or Selection (replaces manual credential prompts)

**Ask:** "Create a new Supabase project or use an existing one? [new/existing]"

**Existing path:**
- Show output of `supabase projects list` for reference
- Ask for project ref

**New path:**
1. Fetch orgs via `supabase orgs list` — auto-select if only one, show numbered menu otherwise
2. Show numbered region menu: us-east-1, us-west-1, eu-west-1, eu-central-1, ap-southeast-1, ap-northeast-1 (and any others the CLI supports)
3. Ask for project name (default: `simcast`)
4. Ask for database password (generate random via `openssl rand -base64 24` if left blank)
5. Run `supabase projects create --name <name> --region <region> --org-id <org> --db-password <pw>`
6. Poll until project is ready (can take 1-2 minutes), show a spinner/dots

### Auto-extract Credentials (replaces manual prompts)

1. Derive URL: `https://{ref}.supabase.co`
2. Extract anon key via `supabase projects api-keys --project-ref {ref}` — parse the `anon` row
3. Remove the three manual credential prompts (ref, URL, anon key)

### Unchanged

- LiveKit credentials remain manual (no CLI available)
- Link, migrations, edge function deploy, secrets, config file generation, npm install — all unchanged
- No new files or dependencies

## Step Sequence

```
[1] Checking prerequisites (Xcode, Node, Supabase CLI, axe)
[2] Supabase login (auto-skip if already logged in)
[3] Supabase project (create new or use existing)
[4] LiveKit credentials (manual)
[5] Linking Supabase project
[6] Running database migrations
[7] Deploying edge functions
[8] Setting LiveKit secrets
[9] Configuring macOS app
[10] Configuring web dashboard
[11] Installing web dependencies
```
