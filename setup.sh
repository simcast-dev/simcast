#!/usr/bin/env bash
set -euo pipefail

# SimCast setup script — configures Supabase, LiveKit, macOS app, and web dashboard
# Run from the repository root: ./setup.sh

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

step=0
step() { step=$((step + 1)); echo -e "\n${BOLD}${CYAN}[$step]${NC} ${BOLD}$1${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
ask()  { echo -en "  ${BOLD}$1${NC} "; read -r REPLY; }

echo -e "${BOLD}"
echo "  ┌─────────────────────────────────────┐"
echo "  │           SimCast Setup              │"
echo "  │  Stream iOS Simulator to the browser │"
echo "  └─────────────────────────────────────┘"
echo -e "${NC}"

# ── Prerequisites ──────────────────────────────────────────────────────────────

step "Checking prerequisites"

command -v xcodebuild >/dev/null 2>&1 && ok "Xcode found" || fail "Xcode not found. Install from the App Store or run: xcode-select --install"
command -v node >/dev/null 2>&1 && ok "Node.js $(node -v) found" || fail "Node.js not found. Install with: brew install node"
command -v supabase >/dev/null 2>&1 && ok "Supabase CLI found" || fail "Supabase CLI not found. Install with: brew install supabase/tap/supabase"
if command -v /opt/homebrew/bin/axe >/dev/null 2>&1; then
  ok "axe CLI found"
else
  warn "axe CLI not found — interactive controls (tap, gesture, type) won't work"
  warn "Install with: brew install cameroncooke/tap/axe"
fi

# ── Supabase login ────────────────────────────────────────────────────────────

step "Supabase login"
if supabase projects list -o json >/dev/null 2>&1; then
  ok "Already logged in"
else
  echo -e "  ${DIM}Opening browser for Supabase login...${NC}"
  supabase login
  supabase projects list -o json >/dev/null 2>&1 || fail "Login failed — please try again"
  ok "Logged in"
fi

# ── Supabase project ─────────────────────────────────────────────────────────

step "Supabase project"
ask "Create a new Supabase project or use an existing one? [new/existing]:"; PROJECT_CHOICE="$REPLY"

if [[ "$PROJECT_CHOICE" == "existing" ]]; then
  echo ""
  echo -e "  ${DIM}Your Supabase projects:${NC}"
  echo ""
  supabase projects list 2>/dev/null | sed 's/^/    /'
  echo ""
  ask "Project Ref:"; SUPABASE_REF="$REPLY"
  [ -z "$SUPABASE_REF" ] && fail "Project ref is required"
else
  # Select organization
  ORG_JSON=$(supabase orgs list -o json 2>/dev/null)
  ORG_COUNT=$(echo "$ORG_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$ORG_COUNT" -eq 1 ]; then
    ORG_ID=$(echo "$ORG_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
    ORG_NAME=$(echo "$ORG_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])")
    ok "Using organization: $ORG_NAME"
  else
    echo ""
    echo -e "  ${DIM}Select an organization:${NC}"
    echo "$ORG_JSON" | python3 -c "
import sys, json
orgs = json.load(sys.stdin)
for i, org in enumerate(orgs, 1):
    print(f'    {i}) {org[\"name\"]}')
"
    echo ""
    ask "Organization [1-$ORG_COUNT]:"; ORG_INDEX="$REPLY"
    [[ "$ORG_INDEX" =~ ^[0-9]+$ ]] || fail "Invalid selection"
    [ "$ORG_INDEX" -ge 1 ] && [ "$ORG_INDEX" -le "$ORG_COUNT" ] || fail "Selection out of range"
    ORG_ID=$(echo "$ORG_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[$((ORG_INDEX - 1))]['id'])")
    ORG_NAME=$(echo "$ORG_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[$((ORG_INDEX - 1))]['name'])")
    ok "Using organization: $ORG_NAME"
  fi

  # Select region
  echo ""
  echo -e "  ${DIM}Select a region:${NC}"
  REGIONS=("us-east-1" "us-west-1" "eu-west-1" "eu-central-1" "ap-southeast-1" "ap-northeast-1" "ap-south-1" "sa-east-1")
  REGION_LABELS=("US East (Virginia)" "US West (Oregon)" "EU West (Ireland)" "EU Central (Frankfurt)" "Asia Pacific (Singapore)" "Asia Pacific (Tokyo)" "Asia Pacific (Mumbai)" "South America (São Paulo)")
  for i in "${!REGIONS[@]}"; do
    echo -e "    $((i + 1))) ${REGION_LABELS[$i]} — ${DIM}${REGIONS[$i]}${NC}"
  done
  echo ""
  ask "Region [1-${#REGIONS[@]}]:"; REGION_INDEX="$REPLY"
  [[ "$REGION_INDEX" =~ ^[0-9]+$ ]] || fail "Invalid selection"
  [ "$REGION_INDEX" -ge 1 ] && [ "$REGION_INDEX" -le "${#REGIONS[@]}" ] || fail "Selection out of range"
  REGION="${REGIONS[$((REGION_INDEX - 1))]}"
  ok "Using region: $REGION"

  # Project name
  echo ""
  ask "Project name [simcast]:"; PROJECT_NAME="${REPLY:-simcast}"

  # Database password
  ask "Database password (leave blank to auto-generate):"; DB_PASSWORD="$REPLY"
  if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(openssl rand -base64 24)
    ok "Generated database password"
  fi

  # Create project
  echo ""
  echo -e "  ${DIM}Creating project '$PROJECT_NAME' in $REGION...${NC}"
  CREATE_OUTPUT=$(supabase projects create "$PROJECT_NAME" \
    --org-id "$ORG_ID" \
    --region "$REGION" \
    --db-password "$DB_PASSWORD" \
    -o json 2>/dev/null)
  SUPABASE_REF=$(echo "$CREATE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['ref'])" 2>/dev/null) \
    || SUPABASE_REF=$(echo "$CREATE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null) \
    || fail "Failed to create project. Output: $CREATE_OUTPUT"
  ok "Project created: $SUPABASE_REF"

  # Wait for project to become healthy
  echo -en "  ${DIM}Waiting for project to be ready"
  for i in $(seq 1 60); do
    STATUS=$(supabase projects list -o json 2>/dev/null \
      | python3 -c "import sys,json; projects=json.load(sys.stdin); print(next((p['status'] for p in projects if p['ref']=='$SUPABASE_REF'),'UNKNOWN'))")
    if [ "$STATUS" = "ACTIVE_HEALTHY" ]; then
      echo -e "${NC}"
      ok "Project is ready"
      break
    fi
    echo -n "."
    sleep 5
  done
  [ "$STATUS" = "ACTIVE_HEALTHY" ] || fail "Project did not become ready after 5 minutes"
fi

# Extract credentials automatically
SUPABASE_URL="https://${SUPABASE_REF}.supabase.co"
SUPABASE_ANON_KEY=$(supabase projects api-keys --project-ref "$SUPABASE_REF" -o json 2>/dev/null \
  | python3 -c "import sys,json; keys=json.load(sys.stdin); print(next(k['api_key'] for k in keys if k.get('name')=='anon'))")
[ -z "$SUPABASE_ANON_KEY" ] && fail "Could not retrieve anon key"
ok "Supabase URL: $SUPABASE_URL"
ok "Anon key retrieved"

# ── LiveKit credentials ──────────────────────────────────────────────────────

step "LiveKit credentials"
echo -e "  ${DIM}Create a project at https://cloud.livekit.io if you haven't already.${NC}"
echo -e "  ${DIM}Find these values in Project Settings → Keys.${NC}"
echo ""
ask "LiveKit URL (e.g. wss://your-app.livekit.cloud):"; LIVEKIT_URL="$REPLY"
ask "LiveKit API Key:"; LIVEKIT_API_KEY="$REPLY"
ask "LiveKit API Secret:"; LIVEKIT_API_SECRET="$REPLY"

[ -z "$LIVEKIT_URL" ] && fail "LiveKit URL is required"
[ -z "$LIVEKIT_API_KEY" ] && fail "LiveKit API key is required"
[ -z "$LIVEKIT_API_SECRET" ] && fail "LiveKit API secret is required"

# ── Supabase setup ─────────────────────────────────────────────────────────────

step "Linking Supabase project"
(cd apps/supabase && supabase link --project-ref "$SUPABASE_REF")
ok "Linked to $SUPABASE_REF"

step "Running database migrations"
(cd apps/supabase && supabase db push)
ok "Migrations applied (tables, RLS policies, storage buckets)"

step "Deploying edge functions"
(cd apps/supabase && supabase functions deploy livekit-token)
(cd apps/supabase && supabase functions deploy livekit-guest-token)
ok "Edge functions deployed"

step "Setting LiveKit secrets"
(cd apps/supabase && supabase secrets set \
  "LIVEKIT_URL=$LIVEKIT_URL" \
  "LIVEKIT_API_KEY=$LIVEKIT_API_KEY" \
  "LIVEKIT_API_SECRET=$LIVEKIT_API_SECRET")
ok "Secrets set"

# ── Web app config ─────────────────────────────────────────────────────────────

step "Configuring web dashboard"
ENVFILE="apps/web/.env.local"
if [ -f "$ENVFILE" ]; then
  warn "$ENVFILE already exists — skipping (delete it and re-run to regenerate)"
else
  cat > "$ENVFILE" <<EOF
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF
  ok "Created $ENVFILE"
fi

step "Installing web dependencies"
(cd apps/web && npm install --silent)
ok "Dependencies installed"

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${GREEN}Setup complete!${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. ${BOLD}Boot a simulator:${NC}"
echo -e "     open -a Simulator"
echo ""
echo -e "  2. ${BOLD}Run the macOS app:${NC}"
echo -e "     open apps/macos/simcast.xcodeproj"
echo -e "     ${DIM}Build and run with Cmd+R. The app will prompt for Supabase URL and Anon Key on first launch.${NC}"
echo -e "     ${DIM}Grant Screen Recording and Accessibility permissions when prompted.${NC}"
echo ""
echo -e "  3. ${BOLD}Run the web dashboard:${NC}"
echo -e "     cd apps/web && npm run dev"
echo -e "     ${DIM}Open http://localhost:3000, sign in, and click Start Stream on a simulator.${NC}"
echo ""
echo -e "  ${DIM}Both apps use the same Supabase email/password account — create one on either side.${NC}"
