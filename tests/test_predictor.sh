#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MINT_PREDICT_TEST_MODE=1 source "$repo_dir/shell/mint-predict.bash"

assert_top() {
  local prefix=$1 expected=$2
  _mint_predict__rank "$prefix"
  [[ ${_MINT_PREDICT_CANDIDATES[0]:-} == "$expected" ]] || {
    printf 'For %q expected %q, got %q\n' "$prefix" "$expected" "${_MINT_PREDICT_CANDIDATES[0]:-}" >&2
    exit 1
  }
}

_MINT_PREDICT_HISTORY=(
  'git status'
  'git switch main'
  'git status'
  'git log --oneline'
  'docker ps'
)

assert_top 'git ' 'git status'
assert_top 'docker' 'docker ps'
_mint_predict__rank 'python'
[[ ${#_MINT_PREDICT_CANDIDATES[@]} == 0 ]]

printf 'predictor tests passed\n'
