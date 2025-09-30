#!/usr/bin/env bash

###
#
# Runs the linting checks for the plugin
#
###

source "$(dirname "$0")/shared"

require_gdlint

gdlint "${PLUGIN_FOLDER}" "${PROJECT_ROOT}/test"
