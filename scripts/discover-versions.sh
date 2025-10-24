#!/bin/bash
set -euo pipefail

# discover-versions.sh
# Discovers available versions from upstream registries and outputs JSON for GitHub Actions matrix
# Usage: ./discover-versions.sh <product> [config-file]
#   product: elasticsearch or opensearch
#   config-file: path to version-config.yml (optional)

PRODUCT="${1:-}"
CONFIG_FILE="${2:-.github/version-config.yml}"
CRANE_VERSION="v0.19.1"

if [[ -z "$PRODUCT" ]]; then
    echo "Error: Product name required (elasticsearch or opensearch)" >&2
    exit 1
fi

# Function to parse YAML config (simple key=value parsing)
get_config() {
    local key="$1"
    local default="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -E "^\s*${key}:" "$CONFIG_FILE" | sed -E 's/^[^:]+:\s*//' || echo "$default"
    else
        echo "$default"
    fi
}

# Get configuration values
MAX_MAJOR_VERSIONS=$(get_config "max_major_versions" "3")
MIN_MAJOR_VERSION=$(get_config "${PRODUCT}_min_major_version" "")

# Determine registry and image based on product
case "$PRODUCT" in
    elasticsearch)
        REGISTRY="docker.elastic.co/elasticsearch/elasticsearch"
        ;;
    opensearch)
        REGISTRY="docker.io/opensearchproject/opensearch"
        ;;
    *)
        echo "Error: Unknown product '$PRODUCT'" >&2
        exit 1
        ;;
esac

echo "🔍 Discovering versions for $PRODUCT from $REGISTRY..." >&2

# Use crane to list all tags
TAGS=$(docker run --rm gcr.io/go-containerregistry/crane:${CRANE_VERSION} ls "$REGISTRY" 2>/dev/null || echo "")

if [[ -z "$TAGS" ]]; then
    echo "Error: Failed to list tags from $REGISTRY" >&2
    exit 1
fi

# Filter and parse versions
# Only include stable releases (x.y.z format), exclude pre-releases
VERSIONS=$(echo "$TAGS" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr || true)

if [[ -z "$VERSIONS" ]]; then
    echo "Error: No valid versions found" >&2
    exit 1
fi

# Extract unique major.minor versions and find latest patch for each
declare -A LATEST_VERSIONS
declare -A MAJOR_VERSION_COUNT

while IFS= read -r version; do
    if [[ -z "$version" ]]; then
        continue
    fi

    # Extract major, minor, patch
    MAJOR=$(echo "$version" | cut -d. -f1)
    MINOR=$(echo "$version" | cut -d. -f2)
    MAJOR_MINOR="${MAJOR}.${MINOR}"

    # Skip if below minimum major version
    if [[ -n "$MIN_MAJOR_VERSION" ]] && [[ "$MAJOR" -lt "$MIN_MAJOR_VERSION" ]]; then
        continue
    fi

    # Track major version count
    if [[ -z "${MAJOR_VERSION_COUNT[$MAJOR]:-}" ]]; then
        MAJOR_VERSION_COUNT[$MAJOR]=1
    fi

    # Keep only the latest patch version for each major.minor
    if [[ -z "${LATEST_VERSIONS[$MAJOR_MINOR]:-}" ]]; then
        LATEST_VERSIONS[$MAJOR_MINOR]="$version"
    fi
done <<< "$VERSIONS"

# Filter to only recent major versions
UNIQUE_MAJORS=($(echo "${!MAJOR_VERSION_COUNT[@]}" | tr ' ' '\n' | sort -Vr))
if [[ ${#UNIQUE_MAJORS[@]} -gt $MAX_MAJOR_VERSIONS ]]; then
    UNIQUE_MAJORS=("${UNIQUE_MAJORS[@]:0:$MAX_MAJOR_VERSIONS}")
fi

echo "📊 Found ${#UNIQUE_MAJORS[@]} major version(s): ${UNIQUE_MAJORS[*]}" >&2

# Build final version list (only from recent major versions)
FINAL_VERSIONS=()
for major_minor in $(echo "${!LATEST_VERSIONS[@]}" | tr ' ' '\n' | sort -V); do
    MAJOR=$(echo "$major_minor" | cut -d. -f1)

    # Check if this major version should be included
    for allowed_major in "${UNIQUE_MAJORS[@]}"; do
        if [[ "$MAJOR" == "$allowed_major" ]]; then
            FINAL_VERSIONS+=("${LATEST_VERSIONS[$major_minor]}")
            break
        fi
    done
done

# Sort final versions
IFS=$'\n' FINAL_VERSIONS=($(sort -Vr <<<"${FINAL_VERSIONS[*]}"))
unset IFS

if [[ ${#FINAL_VERSIONS[@]} -eq 0 ]]; then
    echo "Error: No versions match criteria" >&2
    exit 1
fi

echo "✅ Discovered ${#FINAL_VERSIONS[@]} version(s) to build:" >&2
printf "   - %s\n" "${FINAL_VERSIONS[@]}" >&2

# Output JSON array for GitHub Actions matrix
printf '{"version":['
for i in "${!FINAL_VERSIONS[@]}"; do
    printf '"%s"' "${FINAL_VERSIONS[$i]}"
    if [[ $i -lt $((${#FINAL_VERSIONS[@]} - 1)) ]]; then
        printf ','
    fi
done
printf ']}\n'
