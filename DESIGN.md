# MigrateGuard — Design

### Direction

A calm, dark, developer-tool look, like a test report. The page answers one question quickly: did the migration break anything? Status must be obvious in under two seconds.

### Layout

1. Header: project name, network badge, generated time.
2. Status banner: large PASS or FAIL with counts, for example 4 of 4 invariants passed.
3. Invariant cards in a grid: id, name, status icon, offenders count.
4. Records table with v1 and v2 side by side. Mismatched cells highlighted, missing rows marked.
5. Footer: contract addresses with copy buttons and Etherscan links.

### Components

- StatusBanner, InvariantCard, RecordsTable, AddressChip (0x1234…abcd with copy), Badge.
- Row states: OK, MISMATCH, MISSING, PHANTOM. Each uses color plus an icon plus a text label.

### Typography and spacing

- Body: Inter, system-ui, sans-serif. Addresses and keys: JetBrains Mono, ui-monospace, monospace.
- Base 16px, scale 12, 14, 16, 20, 28. Spacing scale 4, 8, 12, 16, 24, 32. Radius 8.

### Design tokens (CSS)

```css
:root {
  --bg: #0B0F1A; --surface: #121829; --border: #232B42;
  --text: #E6EAF5; --muted: #8F9ABB; --accent: #6C5CE7;
  --pass: #22C55E; --fail: #EF4444; --warn: #F59E0B;
  --radius: 8px;
}
```

### Accessibility

- Never rely on color alone: always pair with an icon and a text label.
- Keep text contrast at WCAG AA or better.
- Tables scroll horizontally on small screens. Layout works down to 360px wide.
- Respect prefers-reduced-motion; use no animation beyond a short fade.
