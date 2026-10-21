#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
opencode_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode"
plugin_dir="${opencode_dir}/plugins/tmux-activity"
command_dir="${opencode_dir}/commands"
cli_config="${opencode_dir}/cli.json"
tmux_config="${HOME}/.tmux.conf"
tmux_source="${repo_dir}/tmux/opencode-activity.conf"
marker="# tmux-opencode activity status"

mkdir -p "${plugin_dir}" "${command_dir}"
cp "${repo_dir}/opencode/plugins/tmux-activity/tui.mjs" "${plugin_dir}/tui.mjs"
cp "${repo_dir}/opencode/plugins/tmux-activity/tmux-summary.sh" "${plugin_dir}/tmux-summary.sh"
cp "${repo_dir}/opencode/plugins/tmux-activity/package.json" "${plugin_dir}/package.json"
chmod +x "${plugin_dir}/tmux-summary.sh"
cp "${repo_dir}/opencode/commands/stage.md" "${command_dir}/stage.md"

python3 - "${cli_config}" "${plugin_dir}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
plugin = sys.argv[2]
config = json.loads(path.read_text()) if path.exists() else {"$schema": "https://opencode.ai/v2/cli.json"}
plugins = config.setdefault("plugins", [])
if plugin not in plugins:
    plugins.append(plugin)
path.write_text(json.dumps(config, indent=2) + "\n")
PY

touch "${tmux_config}"
if ! grep -Fqx "${marker}" "${tmux_config}"; then
    {
        printf '\n%s\n' "${marker}"
        printf 'source-file %s\n' "${tmux_source}"
    } >> "${tmux_config}"
fi

if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "${tmux_config}"
fi

printf 'Installed tmux + OpenCode attention status. Restart OpenCode TUI sessions to load the plugin.\n'
