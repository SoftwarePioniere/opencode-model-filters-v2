#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${OPENCODE_MODEL_FILTERS_REPO:-https://github.com/SoftwarePioniere/opencode-model-filters-v2.git}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_PATH="${OPENCODE_CONFIG:-$CONFIG_HOME/opencode/opencode.json}"
INSTALL_DIR="${OPENCODE_MODEL_FILTERS_DIR:-$CONFIG_HOME/opencode/plugins/opencode-model-filters-v2}"
CONFIG_HOME2="${XDG_CONFIG_HOME:-~/.config}"
INSTALL_DIR2="${OPENCODE_MODEL_FILTERS_DIR:-$CONFIG_HOME2/opencode/plugins/opencode-model-filters-v2}"

command -v git >/dev/null 2>&1 || {
  printf '%s\n' 'Error: git is required to install this plugin.' >&2
  exit 1
}
command -v node >/dev/null 2>&1 || {
  printf '%s\n' 'Error: Node.js is required to update opencode.json.' >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
backup_path=""
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

git clone --depth 1 "$REPO_URL" "$tmp_dir/repo" >/dev/null
mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -e "$INSTALL_DIR" ]; then
  backup_path="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
  mv "$INSTALL_DIR" "$backup_path"
fi
mv "$tmp_dir/repo" "$INSTALL_DIR"

if [ ! -f "$CONFIG_PATH" ]; then
  printf 'Installed plugin at %s\n' "$INSTALL_DIR"
  printf 'Configuration file not found: %s\n' "$CONFIG_PATH"
  printf '%s\n' 'Add the plugin path to the plugin array, then restart OpenCode.'
  exit 0
fi

CONFIG_PATH="$CONFIG_PATH" INSTALL_DIR="$INSTALL_DIR" INSTALL_DIR2="$INSTALL_DIR2" node --input-type=module <<'NODE'
import fs from "node:fs";

const configPath = process.env.CONFIG_PATH;
const installDir2 = process.env.INSTALL_DIR2;
const pluginEntry = installDir2;

let text;
try{
  text = fs.readFileSync(configPath, "utf8");
} catch (error) {
  throw new Error('Currently to stupid to parse jsonc files because of comments etc... Change the config file to .json format')
}

let config;
try {
  config = JSON.parse(text);
} catch (error) {
  throw new Error(`Could not parse ${configPath} as JSON: ${error.message}`);
}

if (!Array.isArray(config.plugin)) {
  config.plugin = [];
}

if (config.plugin.includes(pluginEntry)) {
  console.log(`Plugin already configured: ${pluginEntry}`);
  process.exit(0);
}

config.plugin.push(pluginEntry);

fs.copyFileSync(configPath, `${configPath}.backup.${Date.now()}`);

fs.writeFileSync(
  configPath,
  `${JSON.stringify(config, null, 2)}\n`
);

console.log(`Added plugin entry to ${configPath}`);
NODE


printf 'Installed OpenCode Model Filters V2 at %s\n' "$INSTALL_DIR"
if [ -n "$backup_path" ]; then
  printf 'Previous installation preserved at %s\n' "$backup_path"
fi
printf '%s\n' 'Restart OpenCode to load the plugin.'
