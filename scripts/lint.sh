#!/usr/bin/env bash

###
#
# Runs the linting checks for the plugin
#
###

source "$(dirname "$0")/shared"

GDLINT=$(require_gdlint)

"${GDLINT}" "${PLUGIN_FOLDER}" "${PROJECT_ROOT}/test"
