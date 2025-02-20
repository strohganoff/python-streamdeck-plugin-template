#!/usr/bin/env bash
# Make the script exit on errors, unset variables, and prevent errors in pipelines from being masked.
set -euo pipefail

# Disable exit on non-zero exit codes
set +e

export PYTHON_COMMAND="python3"
export PYTHON_MIN_VERSION="3.8"

export SCRIPT_DIR=$(dirname "$0")
export PLUGIN_NAME=$(basename "$SCRIPT_DIR")
export LOG_FILE="${SCRIPT_DIR}/run.log"

export REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"

export VENV_DIR="${SCRIPT_DIR}/.venv"
export VENV_PYTHON="${VENV_DIR}/bin/python"

# Ensure the log file's directory exists.
# mkdir -p $(dirname "$LOG_FILE")
# TODO: validate this, since it seems to be acting wonky...

# Function to write to both stdout and the log file.
log_echo() {
    echo "$@" | tee -a "$LOG_FILE"
}

# Function to display error messages with an applescript display dialog
display_error() {
    local message="$1"
    osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\""
    exit 1
}

log_echo "Current Working Directory: ${PWD}"


# Check if Python is available
if ! command -v "$PYTHON_COMMAND" &> /dev/null; then
  display_error "Stream Deck plugin '${PLUGIN_NAME}' ERROR\n\n ${PYTHON_COMMAND} not found."
fi

# Check Python version
PYTHON_VERSION_OUTPUT="$(${PYTHON_COMMAND} -V 2>&1)"
log_echo "Python version being used: ${PYTHON_VERSION_OUTPUT}"
log_echo "Env Var 'PYTHONPATH' value: \"$(${PYTHONPATH})\""
PYTHON_VERSION_NUMBER="$(echo $PYTHON_VERSION_OUTPUT | awk '{print $2}')"
if [[ "$(printf '%s\n' "$PYTHON_MIN_VERSION" "$PYTHON_VERSION_NUMBER" | sort -V | head -n1)" != "$PYTHON_MIN_VERSION" ]]; then
  display_error "Stream Deck plugin '${PLUGIN_NAME}' ERROR\n\nPython $PYTHON_MIN_VERSION or higher is required."
fi

# Create virtual environment if it doesn't exist
if [[ ! -d "$VENV_DIR" ]]; then
  log_echo "Creating virtual environment..."
  "$PYTHON_COMMAND" -m venv "$VENV_DIR" || display_error "Failed to create virtual environment."
fi

source "$VENV_DIR"/bin/activate

# Upgrade pip and install/update dependencies
log_echo "installing/updating dependencies..."
"$VENV_PYTHON" -m pip install --upgrade pip || display_error "Failed to upgrade pip."
"$VENV_PYTHON" -m pip install -U -r "$REQUIREMENTS_FILE" 2>&1 | tee -a "$LOG_FILE" || display_error "Failed to install python dependencies."
EXIT_CODE=$?
log_echo "Dependencies installed. ${EXIT_CODE}"


# Check if the plugin was packed with a debug flag file to enable debug mode
DEBUG_OPTS=()
if [[ -f "${SCRIPT_DIR}/.debug" ]]; then
  DEBUG_PORT=$(cat .debug)
  export DEBUG_OPTS=(--debug ${DEBUG_PORT})
  log_echo "Debug mode enabled on port ${DEBUG_PORT}"
fi

# Run the command, and log the exit code.
# log_echo "streamdeck command location: $(which streamdeck)"
# log_echo "streamdeck installed? $(python -m pip list)"
log_echo "Starting Plugin..."
streamdeck "$@" 2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=$?
log_echo "Finished main.py with error code: ${EXIT_CODE}"

exit $EXIT_CODE