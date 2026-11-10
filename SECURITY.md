# Security

## What the app can do on a phone

- **One permission: Internet**, used only to send receipt photos to an OCR server the owner sets up.
  No camera, storage, contacts, location or SMS permissions. Photos come through Android's own camera and
  gallery screens; files through Android's own file picker.
- **Native app, no web view.** Built with Flutter; no web content is loaded, and no remote code runs.
- **No accounts, analytics or ads.** Nothing is sent anywhere except receipt photos to the owner's own server.
- **Data stays on the phone** in the app's private storage. Other apps cannot read it.
- **Release builds** are not debuggable and are signed with a private key kept in GitHub secrets.
  Builds made without that key are marked `-test` and are for testing only.

## Known trade-offs

- **Plain HTTP to the OCR server.** The phone talks to a laptop on the same Wi-Fi or over Tailscale. Over
  Tailscale the link is encrypted (WireGuard). On plain Wi-Fi, receipt photos are visible to others on that
  network. Use Tailscale outside a trusted home network.
- **Android cloud backup is on.** If the owner's Google account backs up apps, the shop data is included
  (encrypted by Android when the phone has a screen lock). This protects against losing the phone; turn off
  app backup in Android settings if that is not wanted.
- **OCR server token.** Set `OCR_TOKEN`; without it anyone on the same network can send images to the laptop.

## Dependencies

Only widely used packages, most published by the Flutter and Dart teams or Flutter Community.
CI runs `flutter analyze`, the unit tests and `pip-audit` before every build. Dependabot opens weekly update
pull requests for Dart packages, Python packages and GitHub Actions.

## Reporting

Open a GitHub issue, or for anything sensitive, a private security advisory on the repository.
