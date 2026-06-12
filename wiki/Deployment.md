# Deployment

## Auto-Deploy (GitHub Actions)

Everglow auto-deploys to Firebase Hosting on every push to the `main` branch.

### Workflow

1. **Checkout** — Pulls the latest code
2. **Setup Flutter** — Installs stable Flutter SDK
3. **Generate Changelog** — Categorizes commits (features, fixes, updates)
4. **Install Dependencies** — `flutter pub get`
5. **Build Web** — `flutter build web --release`
6. **Copy Changelog** — Places `CHANGELOG.md` in `build/web/`
7. **Deploy to Firebase** — Uses `FirebaseExtended/action-hosting-deploy@v0`
8. **Create GitHub Release** — Tags and releases with changelog

### Workflow File

`.github/workflows/deploy.yml`

### Required Secrets

| Secret | Purpose |
|--------|---------|
| `GITHUB_TOKEN` | Auto-provided by GitHub |
| `FIREBASE_SERVICE_ACCOUNT_EVERGLOW_1C6DB` | Firebase admin credentials |

To add the Firebase secret:
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Add `FIREBASE_SERVICE_ACCOUNT_EVERGLOW_1C6DB`
3. Value: Contents of your Firebase admin SDK JSON

## Manual Deploy

```bash
# 1. Build
flutter build web --release

# 2. Deploy to Firebase
firebase deploy --only hosting

# 3. Verify
open https://everglow-1c6db.web.app
```

## Deploy Checklist

Before pushing to `main`:

- [ ] Test locally with `flutter run -d chrome`
- [ ] Build succeeds with `flutter build web --release`
- [ ] No sensitive files committed (API keys, admin SDK)
- [ ] Changelog-worthy commits (feat:, fix:, chore:)
- [ ] Firebase rules are up to date

## Rollback

If a deploy goes wrong:

1. **Via Firebase Console:**
   - Go to Hosting → Releases
   - Find the previous release
   - Click "Rollback"

2. **Via CLI:**
   ```bash
   firebase hosting:rollback
   ```

3. **Via Git:**
   ```bash
   git revert HEAD
   git push origin main
   ```

## Versioning

Versions are auto-generated from dates:
```
YYYY.MM.DD
```

Example: `2026.6.12`

Each deploy creates a GitHub Release with:
- Tag: `v2026.6.12`
- Name: `Release 2026.6.12`
- Body: Auto-generated changelog

## Cache Busting

The following files have `no-cache` headers to ensure users always get the latest:
- `/version.json`
- `/sw.js`
- `/index.html`

## Custom Domain

To add a custom domain:

1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Enter your domain
4. Update DNS records as shown
5. SSL is auto-provisioned by Firebase
