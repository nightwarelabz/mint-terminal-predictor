# Mint Terminal Predictor

Mint Terminal Predictor is a local Bash command predictor for Linux Mint. It
learns from your Bash history and displays the most likely completion directly
beside the command line as you type. Predictions are never executed for you.

## Install

From this repository:

```bash
chmod +x install.sh tests/test_predictor.sh
./install.sh
```

The installer adds a small, marked block to `~/.bashrc` and creates a timestamped
backup first. Open a new terminal afterwards, or run `source ~/.bashrc`.

## Use

Start typing a command that appears in your Bash history. A dim inline bar,
such as `=> status`, is only a visual suggestion; it is not part of the command
you will run.

- `Ctrl` + `Right`: accept the highlighted prediction.
- `Alt` + `Down`: cycle through up to three predictions.
- `Tab`: retains normal Bash completion.
- `mint_predict_reload`: reload command history manually.

Predictions are ranked by how often you have used a matching command, then by
how recently you used it. Everything runs locally in the shell and uses only
the commands already stored in Bash history.

## Configuration

Set these before sourcing `shell/mint-predict.bash` in `~/.bashrc` when you want
different behavior:

```bash
export MINT_PREDICT_HISTORY_LIMIT=5000
export MINT_PREDICT_MAX_SUGGESTIONS=3
export MINT_PREDICT_MIN_PREFIX=1
```

The predictor initially targets Bash, Linux Mint's default shell. The optional
API key setup is not needed for this local version; it can be used later for
natural-language command assistance.

## Test

```bash
tests/test_predictor.sh
```
