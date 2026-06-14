# al-hub npx

Minimal `npx` launcher for `al-hub/npx`.

## Usage

```bash
npx github:al-hub/npx
npx github:al-hub/npx doctor
npx github:al-hub/npx setup
npx github:al-hub/npx monitor
```

Local run:

```bash
node bin/al.js
node bin/al.js doctor
node bin/al.js setup
node bin/al.js monitor
node bin/al.js help
```

## Commands

- `doctor`: environment check
- `setup`: create default folders
- `monitor`: real-time system monitoring
- `exit`: quit the menu

`monitor` prints a compact 4-line dashboard and refreshes the numbers in place.
