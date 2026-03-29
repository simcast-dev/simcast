# SimCast macOS Release Pipeline Design

## Overview

Automated release pipeline for the SimCast macOS app: GitHub Actions builds a signed, notarized, branded DMG on tag push, publishes to GitHub Releases, and updates Sparkle's appcast for auto-updates.

## Release Flow

1. Developer updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode
2. Commits to `main`, tags: `git tag v1.2.3` then `git push origin v1.2.3`
3. GitHub Actions triggers on `v*` tag push and handles everything else automatically

---

## Part 1: One-Time Prerequisites

### 1.1 Create Developer ID Application Certificate

You need a **Developer ID Application** certificate — this is different from the iOS distribution certificates you're used to. It's specifically for macOS apps distributed outside the App Store.

**Step 1 — Generate a Certificate Signing Request (CSR):**

1. Open **Keychain Access** on your Mac
2. Menu bar: Keychain Access > Certificate Assistant > **Request a Certificate From a Certificate Authority**
3. Fill in:
   - **User Email Address:** your Apple ID email
   - **Common Name:** your name (or leave default)
   - **CA Email Address:** leave empty
   - **Request is:** select **Saved to disk**
4. Click Continue, save the `.certSigningRequest` file somewhere you can find it

**Step 2 — Create the certificate in Apple Developer portal:**

1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click the **+** button
3. Under "Software", select **Developer ID Application**
4. Click Continue
5. If asked about an intermediate certificate, select **G2 Sub-CA** (current default)
6. Upload the `.certSigningRequest` file from Step 1
7. Click Continue, then **Download** the `.cer` file
8. Double-click the downloaded `.cer` file — it installs into your Keychain automatically

**Step 3 — Verify installation:**

```bash
security find-identity -v -p codesigning
```

You should see a line like:
```
  1) ABCDEF123456... "Developer ID Application: Your Name (69GA4523WD)"
```

### 1.2 Export .p12 for GitHub Actions

GitHub Actions needs your signing certificate and private key bundled as a `.p12` file.

1. Open **Keychain Access**
2. In the sidebar, select **My Certificates** (under Category)
3. Find **"Developer ID Application: Your Name (69GA4523WD)"**
   - Make sure it has a disclosure triangle (▶) showing the private key underneath — if not, the private key is missing and you need to use the same Mac where you created the CSR
4. Right-click the certificate (not the private key) > **Export "Developer ID Application: ..."**
5. Choose **Personal Information Exchange (.p12)** format
6. Save it (e.g., `SimCast-DeveloperID.p12`)
7. Set a strong password when prompted — you'll store this in GitHub Secrets

**Base64 encode the .p12 for GitHub:**

```bash
base64 -i SimCast-DeveloperID.p12 -o SimCast-DeveloperID-base64.txt
```

Copy the contents of `SimCast-DeveloperID-base64.txt` — this becomes the `APPLE_CERTIFICATE_BASE64` secret.

After storing the secret, **securely delete** both the `.p12` and the base64 file:
```bash
rm SimCast-DeveloperID.p12 SimCast-DeveloperID-base64.txt
```

### 1.3 Create App-Specific Password for Notarization

Apple's notarization service requires authentication. You cannot use your normal Apple ID password; you need an app-specific password.

1. Go to https://account.apple.com/sign-in — sign in with your Apple ID
2. Navigate to **Sign-In and Security** > **App-Specific Passwords**
3. Click **Generate an app-specific password**
4. Label it **"SimCast CI"**
5. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

This becomes the `APPLE_ID_PASSWORD` secret.

### 1.4 Generate Sparkle EdDSA Key Pair

Sparkle uses its own EdDSA (Ed25519) signature to verify updates — separate from Apple's code signing.

**Step 1 — Add Sparkle to the Xcode project first** (see Section 3.1), then build the project once so SPM downloads Sparkle.

**Step 2 — Find and run `generate_keys`:**

```bash
# Find the generate_keys binary in SPM build artifacts
find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -path "*/Sparkle-*" 2>/dev/null

# Run it (use the path from the find command above)
/path/to/generate_keys
```

**Alternative — download Sparkle release and use the bundled tool:**

```bash
# Download latest Sparkle release
curl -L -o /tmp/Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-2.tar.xz
mkdir -p /tmp/Sparkle && tar -xf /tmp/Sparkle.tar.xz -C /tmp/Sparkle

# Generate keys
/tmp/Sparkle/bin/generate_keys
```

**Output:** `generate_keys` prints the **public key** to stdout and stores the private key in your macOS Keychain automatically. Copy the public key — it goes in `Info.plist` as `SUPublicEDKey` (see Section 3.2).

**To retrieve the public key again later:**
```bash
/path/to/generate_keys -p
```

**Step 3 — Export the private key for CI:**

```bash
# Export the private key from Keychain to a file
/path/to/generate_keys -x /tmp/sparkle_private_key.txt

# Copy the contents — this becomes the SPARKLE_PRIVATE_KEY GitHub Secret
cat /tmp/sparkle_private_key.txt

# Securely delete after storing in GitHub Secrets
rm /tmp/sparkle_private_key.txt
```

**To view the public key again later:**
```bash
/path/to/generate_keys -p
```

### 1.5 Configure GitHub Secrets

Go to your GitHub repo: **Settings > Secrets and variables > Actions > New repository secret**

Create each of these:

| Secret | Value | How to get it |
|--------|-------|---------------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded .p12 | Section 1.2 — `base64 -i cert.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password from .p12 export | Section 1.2 — password you set |
| `APPLE_ID` | Your Apple ID email | e.g., `you@example.com` |
| `APPLE_ID_PASSWORD` | App-specific password | Section 1.3 — `xxxx-xxxx-xxxx-xxxx` |
| `APPLE_TEAM_ID` | `69GA4523WD` | Already in your Xcode project |
| `SUPABASE_URL` | Supabase project URL | Same as in `Debug.xcconfig` |
| `SUPABASE_ANON_KEY` | Supabase anon key | Same as in `Debug.xcconfig` |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key | Section 1.4 — exported via `generate_keys -x` |

### 1.6 Create Release Directory

```bash
mkdir -p apps/macos/release
```

---

## Part 2: GitHub Actions Workflow

### 2.1 Export Options Plist

Create `apps/macos/release/export-options.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>69GA4523WD</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

### 2.2 Workflow File

**Requirements:**
- **Runner:** `macos-15`
- **Xcode:** 26.3 (selected explicitly; the runner default is Xcode 16.4 which is incompatible)
- **Minimum macOS:** 15.6
- **Architecture:** arm64 only

Create `.github/workflows/release.yml`:

The workflow YAML is maintained in `.github/workflows/release.yml` — refer to that file for the current version. It is the single source of truth.

### 2.3 Troubleshooting the Workflow

**If notarization fails:**
- Check the log: `xcrun notarytool log <submission-id> --apple-id ... --password ... --team-id ...`
- Common issues: unsigned nested frameworks, hardened runtime not enabled, missing entitlements

**If code signing fails:**
- Verify the certificate is a "Developer ID Application" (not "Apple Development" or "3rd Party Mac Developer")
- Check `security find-identity -v -p codesigning` in the CI logs

**If appcast commit fails:**
- The `GITHUB_TOKEN` might lack push permissions — check repo Settings > Actions > General > Workflow permissions is set to "Read and write permissions"

---

## Part 3: Sparkle Integration in macOS App

### 3.1 Add Sparkle SPM Dependency

In Xcode:

1. Open `simcast.xcodeproj`
2. Select the project in the navigator (top-level blue icon)
3. Select the **project** (not target) in the sidebar
4. Go to **Package Dependencies** tab
5. Click **+**
6. Enter URL: `https://github.com/sparkle-project/Sparkle`
7. Set dependency rule to **Up to Next Major Version**, starting from `2.0.0`
8. Click **Add Package**
9. When prompted which package products to add:
   - Check **Sparkle** — add to the `simcast` target
   - Uncheck AutoUpdate (not needed)
10. Click **Add Package**

### 3.2 Update Info.plist

Add these entries to `apps/macos/simcast/Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/simcast-dev/simcast/main/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_ED_KEY_FROM_GENERATE_KEYS</string>
```

Replace `YOUR_PUBLIC_ED_KEY_FROM_GENERATE_KEYS` with the actual public key from Section 1.4.

### 3.3 Add Sparkle Updater to SimcastApp.swift

Add the import and updater controller:

```swift
import Sparkle

@main
struct SimcastApp: App {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        // ... existing window/scene code ...

        Settings {
            // ... existing settings if any ...
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
```

### 3.4 Add CheckForUpdatesView to SimcastApp.swift

Add the following at the bottom of `SimcastApp.swift` (not a separate file):

```swift
import Combine

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .assign(to: \.canCheckForUpdates, on: self)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self._viewModel = ObservedObject(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}
```

**Note:** `SPUUpdater` does NOT conform to `ObservableObject`. Use a Combine KVO publisher to observe `canCheckForUpdates`.

### 3.5 Create Initial appcast.xml

Create `appcast.xml` in the repo root:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.sparkle-project.org/dtd/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>SimCast</title>
  </channel>
</rss>
```

---

## Part 4: Export Options Plist

Create `apps/macos/release/export-options.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>69GA4523WD</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

---

## Part 5: DMG

No custom background or volume icon for now — just the app icon and Applications drop link.

### Local testing

You can test DMG creation locally before pushing:

```bash
brew install create-dmg

# Stage the .app into a folder (create-dmg expects a source folder)
mkdir -p /tmp/dmg-stage
cp -R ~/Library/Developer/Xcode/DerivedData/simcast-*/Build/Products/Debug/SimCast.app /tmp/dmg-stage/

create-dmg \
  --volname "SimCast" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 80 \
  --icon "SimCast.app" 180 210 \
  --app-drop-link 480 210 \
  --hide-extension "SimCast.app" \
  "SimCast-test.dmg" \
  /tmp/dmg-stage
```

Open the resulting DMG to verify the layout looks right. Adjust icon positions if needed.

---

## Version Scheme

- **Format:** Semantic versioning — `v{major}.{minor}.{patch}` (e.g., `v1.0.0`, `v1.1.0`, `v2.0.0`)
- **Tags:** Git tags on `main` branch, pushed manually by developer
- **Xcode versions:** Updated manually before tagging — `MARKETING_VERSION` matches the tag (without `v` prefix), `CURRENT_PROJECT_VERSION` managed manually
- **Stable releases only** — no beta/pre-release channel

---

## User Experience

### New users:
- Download DMG from GitHub Releases (or simcast.dev in the future)
- Open DMG, drag SimCast to Applications
- App opens without Gatekeeper warning (notarized)

### Existing users:
- Sparkle checks for updates on launch
- Update dialog shows new version details
- One-click update in place
- "Check for Updates" available in app menu

---

## Checklist: First Release

Use this checklist when performing the very first release:

- [ ] Developer ID Application certificate created and installed (Section 1.1)
- [ ] .p12 exported and base64-encoded (Section 1.2)
- [ ] App-specific password generated (Section 1.3)
- [ ] Sparkle EdDSA key pair generated (Section 1.4)
- [ ] All 8 GitHub Secrets configured (Section 1.5)
- [ ] `apps/macos/release/` directory created
- [ ] `apps/macos/release/export-options.plist` created (Part 4)
- [ ] Sparkle added as SPM dependency (Section 3.1)
- [ ] `Info.plist` updated with `SUFeedURL` and `SUPublicEDKey` (Section 3.2)
- [ ] `SimcastApp.swift` updated with Sparkle updater (Section 3.3)
- [ ] `CheckForUpdatesView` added to `SimcastApp.swift` (Section 3.4)
- [ ] `appcast.xml` created in repo root (Section 3.5)
- [ ] `.github/workflows/release.yml` created (Section 2.2)
- [ ] GitHub repo Settings > Actions > Workflow permissions set to "Read and write permissions"
- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` updated in Xcode
- [ ] Build and test locally to verify Sparkle doesn't break anything
- [ ] Commit everything to `main`
- [ ] Tag: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] Watch the Actions tab for the workflow run
- [ ] Verify the GitHub Release was created with the DMG attached
- [ ] Download the DMG, open it, verify layout
- [ ] Drag app to Applications, open it, verify no Gatekeeper warning
- [ ] Verify "Check for Updates" menu item appears and works

---

## Files Summary

### New files:
- `.github/workflows/release.yml` — CI workflow
- `apps/macos/release/export-options.plist` — Xcode export options for Developer ID
- `appcast.xml` — Sparkle update feed (repo root)

### Modified files:
- `apps/macos/simcast.xcodeproj/project.pbxproj` — Sparkle SPM dependency
- `apps/macos/simcast/Info.plist` — `SUFeedURL`, `SUPublicEDKey`
- `apps/macos/simcast/SimcastApp.swift` — Sparkle updater controller + menu commands
