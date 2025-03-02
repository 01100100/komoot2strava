#!/bin/bash
# filepath: /home/dave/Code/komoot2shredva/script.sh

# Exit script if any command fails
set -e

# Create output directory
OUTPUT_DIR="./komoot_data"
mkdir -p "$OUTPUT_DIR"

# Source environment variables from .env file
if [ -f .env ]; then
  source .env
else
  echo "Error: .env file not found" >&2
  exit 1
fi

# Verify required environment variables are set
if [ -z "$KOMOOT_USER_ID" ] || [ -z "$KOMOOT_TOUR_ID" ] || [ -z "$KOMOOT_AUTH_COOKIE" ]; then
  echo "Error: Required environment variables are not set" >&2
  exit 1
fi

# Komoot configuration
KOMOOT_TOURS_URL="https://www.komoot.com/user/${KOMOOT_USER_ID}/tours?type=recorded"
KOMOOT_TOUR_URL="https://www.komoot.com/tour/${KOMOOT_TOUR_ID}"
KOMOOT_API_TOURS_URL="https://api.komoot.de/v007/users/${KOMOOT_USER_ID}/tours"
KOMOOT_API_URL="https://www.komoot.com/api/v007/tours/${KOMOOT_TOUR_ID}"

# Common headers for all curl requests
COMMON_HEADERS=(
  -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0"
  -H "Accept: application/json"
  -H "Accept-Language: en-US,en;q=0.5"
  -H "Accept-Encoding: gzip, deflate, br, zstd"
  -H "Alt-Used: www.komoot.com"
  -H "Connection: keep-alive"
  -H "Cookie: ${KOMOOT_AUTH_COOKIE}"
  -H "Sec-Fetch-Dest: empty"
  -H "Sec-Fetch-Mode: cors"
  -H "Sec-Fetch-Site: same-origin"
  -H "Priority: u=0"
  -H "Pragma: no-cache"
  -H "Cache-Control: no-cache"
)

# Function to make a curl request with common headers
function komoot_request() {
    local url="$1"
    local output_file="$2"
    local additional_headers=("${@:3}")
    
    echo "Fetching data from: $url"
    if ! curl --compressed "${COMMON_HEADERS[@]}" "${additional_headers[@]}" "$url" -o "$output_file"; then
        echo "Error: Failed to fetch data from $url" >&2
        return 1
    fi
    echo "Data saved to: $output_file"
    return 0
}

# Get all recorded tours for the user
echo "Fetching tours for user ${KOMOOT_USER_ID}..."
komoot_request "$KOMOOT_TOURS_URL" "$OUTPUT_DIR/all_tours.json" -H "onlyprops: true"

# Get specific tour details
echo "Fetching details for tour ${KOMOOT_TOUR_ID}..."
komoot_request "$KOMOOT_TOUR_URL" "$OUTPUT_DIR/tour_${KOMOOT_TOUR_ID}.json" \
    -H "onlyprops: true" \
    -H "Referer: ${KOMOOT_TOURS_URL}"

# Download GPX for the tour (via API)
echo "Downloading GPX from API for tour ${KOMOOT_TOUR_ID}..."
komoot_request "${KOMOOT_API_URL}.gpx?hl=en" "$OUTPUT_DIR/tour_${KOMOOT_TOUR_ID}.gpx" \
    -H "Accept: application/gpx+xml" \
    -H "Referer: ${KOMOOT_TOUR_URL}"

echo "All data has been successfully downloaded to $OUTPUT_DIR"

# Validate GPX files
for gpx_file in "$OUTPUT_DIR"/*.gpx; do
    if grep -q "<gpx" "$gpx_file"; then
        echo "✓ Valid GPX file: $gpx_file"
    else
        echo "✗ Invalid or empty GPX file: $gpx_file"
    fi
done