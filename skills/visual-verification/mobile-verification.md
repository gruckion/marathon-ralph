# Mobile Verification

Mobile app verification support is planned for a future release.

## Planned Approaches

- Appium MCP for native app testing
- Mobile browser testing via Playwright
- Device emulation

## Current Workaround

For mobile web apps, use browser verification with mobile viewport:

1. Use Playwright MCP to open the app
2. Set viewport to mobile dimensions
3. Follow standard browser verification workflow
