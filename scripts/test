#!/usr/bin/env bash

###
#
# Runs the Unit Tests for the plugin
#
###

source "$(dirname "$0")/shared"

require_godot

PWD=`pwd`
DIRNAME=`dirname "${BASH_SOURCE[0]}"`
REPO_ROOT="${DIRNAME}/.."
GUT="${REPO_ROOT}/addons/gut/gut_cmdln.gd"

"${GODOT}" --headless -s "${GUT}" -d --path "${PWD}"
