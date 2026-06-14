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
- `ccusage`: session summary for token usage and cost
- `tokens`: real-time token usage monitoring
- `exit`: quit the menu

`monitor` prints a compact dashboard with system, CPU, memory, GPU VRAM, disk, and network info, and refreshes the numbers in place.
`ccusage` groups JSONL log entries by session, then summarizes input/output/total tokens and cost per session. Cost is taken from `cost_usd` or `usd` when present; otherwise it can be estimated from an optional tab-separated price file at `~/.al/ccusage-prices.tsv` or `CCUSAGE_PRICE_FILE`, with rows in `model<TAB>input_per_million<TAB>output_per_million` format.
`tokens` is the live watch mode for the same log source. By default both commands read `~/.al/token-usage.log`, or `TOKEN_LOG_FILE` if you set it.
