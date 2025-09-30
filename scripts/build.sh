#!/usr/bin/env bash

###
#
# Creates a zip with the need files to import the plugin in Godot
#
###

source "$(dirname "$0")/shared"


# Define a cleanup function to run at the end, no matter what
cleanup() {
  if [ -f "$temp_file" ]; then
    rm "$temp_file"
  fi
}

# Register the cleanup function to run on exit
trap cleanup EXIT

# Create a temporal file
temp_file=$(mktemp)

# Calculate variables to use
zip_file="${OUTPUT_FOLDER}/$(basename "${PLUGIN_FOLDER}")-${PLUGIN_VERSION}.zip"
# Initial dot needs to be removed for paths to be preserved
find "${PLUGIN_FOLDER}" -type f ! -name "*.uid" | sed 's|^\./||' > "${temp_file}"

# Inject the version from the class into the plugin config
sed -i.bak -E "s/^(version\s*=\s*['\"])[^'\"]+/\\1${PLUGIN_VERSION}/" "${PLUGIN_CONFIG_FILE}"

# Output feedback
echo -e "Creating a .zip file for ${COLOR_NAME}${PLUGIN_NAME} ${COLOR_VERSION}v${PLUGIN_VERSION}${COLOR_RESET} > ${COLOR_FILE}${zip_file}${COLOR_RESET}"
while IFS= read -r file; do
  echo -e "${COLOR_DIM} - ${file}${COLOR_RESET}"
done < "${temp_file}"
echo

# If the output file existed, remove it
if [ -f "$zip_file" ]; then
  rm "$zip_file"
fi

# Create the zip file
"$SEVEN_ZIP" a "$zip_file" @"${temp_file}" | grep -E "(Add new data)|(Everything is Ok)"

# Revert the changes done in the plugin config (in case of running it in local)
mv "${PLUGIN_CONFIG_FILE}".bak "${PLUGIN_CONFIG_FILE}"
