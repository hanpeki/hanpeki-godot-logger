#!/usr/bin/env bash

###
#
# Run this file once after cloning to enable repo-managed Git hooks
#
###

source "$(dirname "$0")/shared"

if [ ! -d "${PROJECT_ROOT}/.git" ]; then
  fail "This script requires a git repository"
fi

info "Setting up git hooks..."
GIT_HOOKS=".githooks"

# Set the hooks path to the repo's .githooks directory
git config core.hooksPath "${GIT_HOOKS}"

# Ensure hooks are executable
chmod +x "${PROJECT_ROOT}/${GIT_HOOKS}"/*

info "  git hooks enabled! ${COLOR_DIM}(core.hooksPath = ${GIT_HOOKS})${COLOR_RESET}"

info "Done!"