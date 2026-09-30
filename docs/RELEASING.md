# Releasing the open-source edition

Downloads outside the Mac App Store must be signed with a **Developer ID** certificate and **notarized** by Apple, otherwise macOS Gatekeeper blocks them.

## One-time setup

1. **Developer ID Application certificate.** Xcode → Settings → Accounts → your team → Manage Certificates → “+” → *Developer ID Application*. (The *Apple Distribution* certificate used for the App Store cannot sign direct downloads.)
2. **Notarization credentials.** Create an app-specific password at appleid.apple.com, then store it in the keychain:
   ```bash
   xcrun notarytool store-credentials "seeyourdisk-notary" \
     --apple-id "<your Apple ID>" --team-id X6C6J5GZ75 --password "<app-specific password>"
   ```
3. **GitHub CLI:** `brew install gh` and `gh auth login`.

## Make a release

```bash
git checkout open-source
scripts/release.sh 1.0.0
```

The script archives, exports with Developer ID, notarizes and staples the app, builds a DMG, notarizes the DMG, writes a SHA-256 file and creates the GitHub release with both files attached.

Never commit certificates, `.p12` files, passwords or the `build/` folder (they are in `.gitignore`).
