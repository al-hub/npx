#!/usr/bin/env node

const { spawnSync } = require("child_process");
const path = require("path");

const args = process.argv.slice(2);
const script = path.join(__dirname, "..", "scripts", "menu.sh");

const result = spawnSync("bash", [script, ...args], {
  stdio: "inherit",
});

process.exit(result.status ?? 1);
