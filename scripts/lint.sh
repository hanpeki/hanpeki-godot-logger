#!/usr/bin/env bash

###
#
# Runs the linting checks for the plugin
#
###

source "$(dirname "$0")/shared"

# Every file and folder in the plugin (including the plugin folder itself) must be snake_case,
# with optional lowercase extensions (i.e. `logger_file_transport.gd.uid`)
SNAKE_CASE_REGEX='^[a-z0-9]+(_[a-z0-9]+)*(\.[a-z0-9]+)*$'
# Conventional names allowed even if they don't follow snake_case
SNAKE_CASE_EXCEPTIONS=("LICENSE" "README.md")

invalid_names=()
while IFS= read -r path; do
  name=$(basename "${path}")
  if [[ ! "${name}" =~ ${SNAKE_CASE_REGEX} && ! " ${SNAKE_CASE_EXCEPTIONS[*]} " =~ " ${name} " ]]; then
    invalid_names+=("${path}")
  fi
done < <(find "${PLUGIN_FOLDER}")

if [[ ${#invalid_names[@]} -gt 0 ]]; then
  for path in "${invalid_names[@]}"; do
    echo -e " - ${COLOR_FILE}${path}${COLOR_RESET} is not snake_case"
  done
  fail "${#invalid_names[@]} file(s) not following the snake_case naming convention"
fi

GDLINT=$(require_gdlint)

"${GDLINT}" "${PLUGIN_FOLDER}" "${PROJECT_ROOT}/test"
