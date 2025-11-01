# Privacy Policy for Img2LaTeX

**Last Updated: November 1, 2025**

## Overview

Img2LaTeX is committed to protecting your privacy. This privacy policy explains our data collection, usage, and storage practices.

## TL;DR - Our Privacy Promise

**We collect ZERO personal data. Everything runs on your device. Your images and documents never leave your iPhone.**

---

## Data Collection

### What We DO NOT Collect

- ❌ Personal information (name, email, phone number)
- ❌ Images or photos you process
- ❌ Generated LaTeX code or PDFs
- ❌ Usage analytics or telemetry
- ❌ Device identifiers or advertising IDs
- ❌ Location data
- ❌ Crash reports (unless you explicitly share via iOS)
- ❌ Any data transmitted to external servers

### What We DO Collect

**Nothing.** Img2LaTeX collects zero data from users.

---

## How Your Data is Processed

### 100% On-Device Processing

All AI inference, image processing, LaTeX generation, and PDF rendering occur **entirely on your device**:

1. **Images**: Processed locally using on-device AI models (Gemma 3N via MediaPipe)
2. **LaTeX Code**: Generated on-device and stored only in your device's local storage
3. **PDFs**: Rendered client-side using WKWebView and latex.js
4. **History**: Saved locally using SwiftData (Apple's local database framework)

### Network Usage

Img2LaTeX uses your internet connection **only** for:

1. **Initial Model Download**: First-time download of AI models (~500MB-900MB) from Cloudflare R2
   - Models are downloaded once and cached locally
   - No personal data is transmitted during download
   - Download URLs are public and do not track users

2. **Optional Updates**: If you choose to download additional models or updates

**After initial setup, the app works 100% offline.** You can enable Airplane Mode and the app will function normally.

---

## Data Storage

### Local Storage Only

All app data is stored locally on your device using:

- **SwiftData**: Apple's framework for local data persistence
- **File System**: Model files cached in app's local directory
- **UserDefaults**: App settings and preferences

### What's Stored Locally

- AI model files (downloaded once, ~500MB-900MB)
- Your generation history (images, LaTeX code, PDFs)
- App settings and preferences
- Favorited generations

### Data Deletion

You have complete control over your data:

- **Delete Individual Items**: Swipe to delete any generation from History
- **Clear All History**: Use Settings to clear all saved generations
- **Uninstall App**: Deleting the app removes ALL data permanently

---

## Third-Party Services

### AI Models

- **Provider**: Google (Gemma 3N models)
- **Usage**: Models run entirely on-device via MediaPipe
- **Data Sharing**: Zero. Models process data locally without any network transmission

### Model Hosting

- **Provider**: Cloudflare R2 (public CDN)
- **Usage**: One-time model download
- **Data Collected**: Standard CDN logs (IP address, download timestamp) - NOT collected by us
- **Privacy Policy**: [Cloudflare Privacy Policy](https://www.cloudflare.com/privacypolicy/)

### Open Source Libraries

Img2LaTeX uses the following open-source libraries:

- **MediaPipe Tasks GenAI** (Google): On-device AI inference
- **ZIPFoundation**: Model file extraction
- **latex.js** (Michael Bui): Client-side LaTeX rendering

These libraries run locally and do not transmit data.

---

## Children's Privacy

Img2LaTeX does not collect any personal information from anyone, including children under 13. The app is safe for all ages (rated 4+).

---

## Data Security

### On-Device Security

Your data is protected by:

- **iOS Sandbox**: App data is isolated from other apps
- **File System Encryption**: iOS encrypts all app data at rest
- **No Cloud Sync**: Data never leaves your device
- **No Authentication**: No accounts, passwords, or login credentials required

### Model Integrity

AI models are downloaded over HTTPS and verified by iOS before use.

---

## Your Rights

Since we collect zero personal data, there is no data to:

- Request access to
- Request deletion of
- Request portability of
- Opt out of

All your data is already under your complete control on your device.

---

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted:

- In the app (if applicable)
- On our GitHub repository: [github.com/youneslaaroussi/Pic2PDF](https://github.com/youneslaaroussi/Pic2PDF)
- On the App Store (via app updates)

Continued use of the app after changes constitutes acceptance of the updated policy.

---

## Open Source Transparency

Img2LaTeX is fully open-source. You can verify our privacy claims by reviewing the source code:

**GitHub Repository**: [github.com/youneslaaroussi/Pic2PDF](https://github.com/youneslaaroussi/Pic2PDF)

---

## Contact

For privacy questions or concerns:

- **Email**: hello@youneslaaroussi.ca
- **GitHub Issues**: [github.com/youneslaaroussi/Pic2PDF/issues](https://github.com/youneslaaroussi/Pic2PDF/issues)

---

## Legal

**Developer**: Younes Laaroussi / DeepShot, Inc.

**Jurisdiction**: This privacy policy is governed by the laws of Canada.

**Compliance**:
- ✅ GDPR Compliant (EU): No personal data collected
- ✅ CCPA Compliant (California): No personal data sold or shared
- ✅ COPPA Compliant (USA): Safe for children under 13
- ✅ PIPEDA Compliant (Canada): No personal information collected

---

## Summary

**Img2LaTeX is privacy-first by design:**

1. ✅ Zero data collection
2. ✅ 100% on-device processing
3. ✅ No cloud servers
4. ✅ No analytics or tracking
5. ✅ No accounts or authentication
6. ✅ Open-source and verifiable
7. ✅ Works offline after initial setup

**Your data is yours. Always.**

---

*This privacy policy is effective as of November 1, 2025.*

