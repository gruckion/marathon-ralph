# Browser Verification with Playwright MCP

Verify web features through actual browser interaction using Playwright MCP.

## Available Tools

| **Tool**                                  | **Purpose**                         |
|-------------------------------------------|-------------------------------------|
| `mcp__playwright__browser_navigate`       | Navigate to URL                     |
| `mcp__playwright__browser_snapshot`       | Get accessibility tree snapshot     |
| `mcp__playwright__browser_screenshot`     | Capture visual screenshot           |
| `mcp__playwright__browser_click`          | Click elements by text/selector     |
| `mcp__playwright__browser_fill`           | Fill form inputs                    |
| `mcp__playwright__browser_select`         | Select dropdown options             |
| `mcp__playwright__browser_wait_for`       | Wait for elements/time              |

## Standard Workflow

### 1. Start Dev Server

```bash
nr dev
```

### 2. Navigate to Feature

```markdown
browser_navigate({ url: "http://localhost:3000/feature-path" })
```

### 3. Wait for Load

```markdown
browser_wait_for({ time: 3 })
```

### 4. Get Page Snapshot

```markdown
browser_snapshot
```

Review the accessibility tree for expected elements.

### 5. Test Interactions

```markdown
browser_fill({ selector: "[name='email']", value: "test@example.com" })
browser_click({ text: "Submit" })
```

### 6. Capture Evidence

```markdown
browser_screenshot
```

## Verification Points

- **Layout**: Elements render correctly, no overlapping
- **Functionality**: Buttons, forms, navigation work
- **Console**: No errors or warnings
- **States**: Loading, empty, error states display correctly

## Common Issues

### Hydration Errors

- Tests can pass while hydration is broken
- Run `npm run build` to catch SSR issues
- Never nest interactive elements (`<button>` inside `<button>`)

### False Positives

- Dev mode often hides errors that production reveals
- Always verify production build before marking complete
