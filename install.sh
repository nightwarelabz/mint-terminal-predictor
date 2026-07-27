#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shell_rc=${1:-"$HOME/.bashrc"}
source_line="source \"$repo_dir/shell/mint-predict.bash\""
begin='# >>> mint-terminal-predictor >>>'
end='# <<< mint-terminal-predictor <<<'

if [[ ! -f $shell_rc ]]; then
  printf 'Refusing to create missing shell file: %s\n' "$shell_rc" >&2
  exit 1
fi

if grep -Fqx "$begin" "$shell_rc"; then
  printf 'mint-predict is already installed in %s\n' "$shell_rc"
  exit 0
fi

backup="${shell_rc}.mint-predict.bak.$(date +%Y%m%d%H%M%S)"
cp -- "$shell_rc" "$backup"
{
  printf '\n%s\n' "$begin"
  printf '%s\n' "$source_line"
  printf '%s\n' "$end"
} >> "$shell_rc"

printf 'Installed in %s (backup: %s)\n' "$shell_rc" "$backup"
printf 'Open a new Bash terminal, or run: source %q\n' "$shell_rc"
