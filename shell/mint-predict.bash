#!/usr/bin/env bash
# mint-terminal-predictor: lightweight, local command predictions for Bash.
# Source this file from an interactive Bash session; do not execute it directly.

if [[ ${MINT_PREDICT_TEST_MODE:-0} != 1 && $- != *i* ]]; then
  return 0 2>/dev/null || exit 0
fi

if [[ ${_MINT_PREDICT_LOADED:-0} == 1 ]]; then
  return 0 2>/dev/null || exit 0
fi
readonly _MINT_PREDICT_LOADED=1

: "${MINT_PREDICT_HISTORY_LIMIT:=3000}"
: "${MINT_PREDICT_MIN_PREFIX:=1}"
: "${MINT_PREDICT_MAX_SUGGESTIONS:=3}"

declare -ga _MINT_PREDICT_HISTORY=()
declare -ga _MINT_PREDICT_CANDIDATES=()
declare -gi _MINT_PREDICT_SELECTED=0
declare -gi _MINT_PREDICT_LAST_HISTCMD=-1
declare -gi _MINT_PREDICT_HINT_VISIBLE=0

_mint_predict__load_history() {
  local -a recent=()

  # HISTTIMEFORMAT= avoids timestamps in history output.  The history builtin
  # also includes commands issued in this running shell, unlike ~/.bash_history.
  mapfile -t recent < <(
    HISTTIMEFORMAT= builtin history |
      sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*//' |
      tail -n "$MINT_PREDICT_HISTORY_LIMIT"
  )

  _MINT_PREDICT_HISTORY=("${recent[@]}")
  _MINT_PREDICT_LAST_HISTCMD=${HISTCMD:-0}
}

_mint_predict__sync_history() {
  local current=${HISTCMD:-0}
  if (( current != _MINT_PREDICT_LAST_HISTCMD )); then
    _mint_predict__load_history
  fi
}

_mint_predict__clear_hint() {
  if (( _MINT_PREDICT_HINT_VISIBLE )); then
    # The cursor is restored to the readline cursor after each rendered hint.
    printf '\e[K'
    _MINT_PREDICT_HINT_VISIBLE=0
  fi
}

_mint_predict__rank() {
  local prefix=$1 command candidate score
  local -i index count=0 best_score=-1
  local -a best_scores=() best_commands=()
  declare -A frequency=() last_seen=()

  _MINT_PREDICT_CANDIDATES=()
  _MINT_PREDICT_SELECTED=0

  [[ ${#prefix} -ge $MINT_PREDICT_MIN_PREFIX ]] || return 0

  # Exact prefix matching keeps every prediction executable as-is. Frequency is
  # weighted most heavily, with recency breaking ties.
  for index in "${!_MINT_PREDICT_HISTORY[@]}"; do
    command=${_MINT_PREDICT_HISTORY[index]}
    [[ -n $command && $command != "$prefix" && $command == "$prefix"* ]] || continue
    ((frequency["$command"] += 1))
    last_seen["$command"]=$index
  done

  for candidate in "${!frequency[@]}"; do
    score=$(( frequency["$candidate"] * 1000000 + last_seen["$candidate"] ))
    for ((index = 0; index < MINT_PREDICT_MAX_SUGGESTIONS; index++)); do
      if (( index >= ${#best_scores[@]} || score > best_scores[index] )); then
        best_scores=("${best_scores[@]:0:index}" "$score" "${best_scores[@]:index}")
        best_commands=("${best_commands[@]:0:index}" "$candidate" "${best_commands[@]:index}")
        break
      fi
    done
  done

  _MINT_PREDICT_CANDIDATES=("${best_commands[@]:0:MINT_PREDICT_MAX_SUGGESTIONS}")
}

_mint_predict__safe_display() {
  local text=$1
  # Do not replay terminal control characters that may have been saved in history.
  if [[ $text =~ [$'\001'-$'\037'$'\177'] ]]; then
    printf '%q' "$text"
  else
    printf '%s' "$text"
  fi
}

_mint_predict__render() {
  local line=${READLINE_LINE-} point=${READLINE_POINT-0}
  local candidate display suffix max=48 visible_length

  _mint_predict__clear_hint
  (( point == ${#line} )) || return 0

  _mint_predict__rank "$line"
  ((${#_MINT_PREDICT_CANDIDATES[@]})) || return 0

  candidate=${_MINT_PREDICT_CANDIDATES[_MINT_PREDICT_SELECTED]}
  suffix=${candidate#"$line"}
  display=$(_mint_predict__safe_display "$suffix")
  if (( ${#display} > max )); then
    display="${display:0:max-3}..."
  fi

  # This is deliberately an inline bar rather than a second terminal line: it
  # never becomes part of READLINE_LINE and it does not disturb command output.
  printf '  \e[2m=> %s\e[0m' "$display"
  visible_length=$((5 + ${#display}))
  printf '\e[%dD' "$visible_length"
  _MINT_PREDICT_HINT_VISIBLE=1
}

_mint_predict__insert_code() {
  local -i code=$1
  local character
  printf -v character "\\$(printf '%03o' "$code")"
  READLINE_LINE="${READLINE_LINE:0:READLINE_POINT}${character}${READLINE_LINE:READLINE_POINT}"
  ((READLINE_POINT++))
  _mint_predict__render
}

_mint_predict__backspace() {
  _mint_predict__clear_hint
  if (( READLINE_POINT > 0 )); then
    READLINE_LINE="${READLINE_LINE:0:READLINE_POINT-1}${READLINE_LINE:READLINE_POINT}"
    ((READLINE_POINT--))
  fi
  _mint_predict__render
}

_mint_predict_accept() {
  _mint_predict__clear_hint
  ((${#_MINT_PREDICT_CANDIDATES[@]})) || return 0
  READLINE_LINE=${_MINT_PREDICT_CANDIDATES[_MINT_PREDICT_SELECTED]}
  READLINE_POINT=${#READLINE_LINE}
}

_mint_predict_next() {
  _mint_predict__clear_hint
  ((${#_MINT_PREDICT_CANDIDATES[@]})) || {
    _mint_predict__render
    return 0
  }
  _MINT_PREDICT_SELECTED=$(( (_MINT_PREDICT_SELECTED + 1) % ${#_MINT_PREDICT_CANDIDATES[@]} ))
  _mint_predict__render
}

mint_predict_reload() {
  _mint_predict__load_history
  printf 'mint-predict: loaded %d commands from Bash history\n' "${#_MINT_PREDICT_HISTORY[@]}"
}

_mint_predict__on_prompt() {
  _mint_predict__clear_hint
  _mint_predict__sync_history
}

_mint_predict__bind_key() {
  local map=$1 code=$2 key
  printf -v key '\\%03o' "$code"
  bind -m "$map" -x "\"$key\":_mint_predict__insert_code $code" 2>/dev/null
}

_mint_predict__install_bindings() {
  local map code
  for map in emacs-standard vi-insertion; do
    for ((code = 32; code <= 126; code++)); do
      _mint_predict__bind_key "$map" "$code"
    done
    # Readline treats the literal space key specially on some distributions;
    # bind it explicitly so a new command word refreshes the prediction.
    bind -m "$map" -x '" ":_mint_predict__insert_code 32' 2>/dev/null
    bind -m "$map" -x '"\C-h":_mint_predict__backspace' 2>/dev/null
    bind -m "$map" -x '"\C-?":_mint_predict__backspace' 2>/dev/null
    bind -m "$map" -x '"\e[3~":_mint_predict__backspace' 2>/dev/null
    # Ctrl+Right accepts the highlighted command; Alt+Down cycles candidates.
    bind -m "$map" -x '"\e[1;5C":_mint_predict_accept' 2>/dev/null
    bind -m "$map" -x '"\e\e[C":_mint_predict_accept' 2>/dev/null
    bind -m "$map" -x '"\e[1;3B":_mint_predict_next' 2>/dev/null
  done
}

_mint_predict__load_history

if [[ ${MINT_PREDICT_TEST_MODE:-0} != 1 ]]; then
  _mint_predict__install_bindings
  if declare -p PROMPT_COMMAND 2>/dev/null | grep -q '^declare -a'; then
    PROMPT_COMMAND+=(_mint_predict__on_prompt)
  elif [[ ${PROMPT_COMMAND:-} != *'_mint_predict__on_prompt'* ]]; then
    PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND}; }_mint_predict__on_prompt"
  fi
fi
