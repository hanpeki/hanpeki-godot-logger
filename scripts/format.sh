#!/usr/bin/env bash

###
#
# Automatically format the files to comply with linting rules
#
###

source "$(dirname "$0")/shared"

require_gdformat

gdformat "${PLUGIN_FOLDER}" "${PROJECT_ROOT}/test"
