# al-hub npx

Minimal `npx` launcher for `al-hub/npx`.

## Usage

```bash
npx github:al-hub/npx
npx github:al-hub/npx doctor
npx github:al-hub/npx setup
npx github:al-hub/npx monitor
npx github:al-hub/npx tokens
```

Local run:

```bash
node bin/al.js
node bin/al.js doctor
node bin/al.js setup
node bin/al.js monitor
node bin/al.js tokens
node bin/al.js help
```

## Commands

- `doctor`: environment check
- `setup`: create default folders
- `monitor`: real-time system monitoring
- `tokens`: real-time token usage monitoring from a JSONL log
- `exit`: quit the menu

`monitor` prints a compact dashboard with system, CPU, memory, GPU VRAM, disk, and network info, and refreshes the numbers in place.
`tokens` watches a token usage log and aggregates `input_tokens`, `output_tokens`, and `total_tokens` values from each entry. By default it reads `~/.al/token-usage.log`, or `TOKEN_LOG_FILE` if you set it.
