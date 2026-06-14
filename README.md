# al-hub npx

Minimal `npx` launcher for `al-hub/npx`.

## Usage

```bash
npx github:al-hub/npx
npx github:al-hub/npx doctor
npx github:al-hub/npx setup
npx github:al-hub/npx monitor
npx github:al-hub/npx ccusage
npx github:al-hub/npx ccusage --watch
npx github:al-hub/npx tokens
```

Local run:

```bash
node bin/al.js
node bin/al.js doctor
node bin/al.js setup
node bin/al.js monitor
node bin/al.js ccusage
node bin/al.js ccusage --watch
node bin/al.js tokens
node bin/al.js help
```

## Commands

- `doctor`: environment check
- `setup`: create default folders
- `monitor`: real-time system monitoring
- `ccusage`: session table for token usage and cost
- `tokens`: live token monitor for the current session/workspace
- `exit`: quit the menu

`monitor` prints a compact dashboard with system, CPU, memory, GPU VRAM, disk, and network info, and refreshes the numbers in place.
`ccusage` reads the Codex state database at `~/.codex/state_*.sqlite` and summarizes sessions from the `threads` table. It shows session token counts, model, title, and last update time. Cost is shown when a TSV price file exists at `~/.codex/ccusage-prices.tsv` or `CCUSAGE_PRICE_FILE`; the file should use `model<TAB>usd_per_million_tokens` rows.
`tokens` is a live counter view for the same Codex state database. It focuses on the latest session, total tokens in scope, and recent sessions so it is visually different from the `ccusage` table. By default both commands scope to the current workspace path and fall back to all sessions if that scope has no rows. Use `--all` to show everything.
