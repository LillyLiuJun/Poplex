#!/usr/bin/env bash
set -euo pipefail

# Shared by local verification and GitHub Actions. IOS_SIMULATOR_DESTINATION
# pins a device name; it is resolved to a UDID so duplicate names cannot fail
# the build. When the device is missing (e.g. hosted runner images rotate
# their device sets), the script falls back to the iPhone with the newest OS
# version instead of failing with an opaque "device not found" error.
project="AIEnglishApp.xcodeproj"
scheme="AIEnglishApp"
derived_data_path="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/AIEnglishApp-DerivedData}"
source_packages_path="${CLONED_SOURCE_PACKAGES_DIR_PATH:-$derived_data_path/SourcePackages}"

available_devices="$(xcrun simctl list devices available)"

# Resolve the preferred device to a UDID. UDID-based destinations survive both
# missing devices (hosted runner images rotate their device sets) and duplicate
# names (e.g. a cloned "iPhone 17 Pro" alongside the stock one, which makes
# name-based destinations fail with "multiple matching destinations").
preferred_destination="${IOS_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"
preferred_device="$(printf '%s' "$preferred_destination" | sed -n 's/.*name=\([^,]*\).*/\1/p')"
# The trailing " (" anchors the whole device name, so "iPhone 16 Pro" does
# not match an "iPhone 16 Pro Max" on images that only ship the Max variant.
preferred_udid="$(printf '%s' "$available_devices" \
  | grep -F "$preferred_device (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' | head -1 || true)"

if [ -n "$preferred_udid" ]; then
  if [ "$(printf '%s' "$available_devices" | grep -Fc "$preferred_device (")" -gt 1 ]; then
    echo "Multiple '$preferred_device' devices found; using $preferred_udid." >&2
  fi
  destination="platform=iOS Simulator,id=$preferred_udid"
else
  # Fall back to the iPhone with the newest OS version. simctl groups devices
  # under `-- iOS X.Y --` headers, so track the header while scanning.
  fallback_udid="$(printf '%s' "$available_devices" | awk '
    /^-- iOS/ { split($3, v, "."); maj = v[1] + 0; min = v[2] + 0 }
    /iPhone [0-9]/ {
      match($0, /\([0-9A-F-]{36}\)/);
      if (RSTART > 0 && (maj > bmaj || (maj == bmaj && min > bmin))) {
        best = substr($0, RSTART + 1, 36); bmaj = maj; bmin = min
      }
    }
    END { print best }')"
  if [ -z "$fallback_udid" ]; then
    echo "error: no available iPhone simulator found." >&2
    printf '%s\n' "$available_devices" >&2
    exit 1
  fi
  echo "Preferred simulator '$preferred_device' is unavailable; using $fallback_udid." >&2
  destination="platform=iOS Simulator,id=$fallback_udid"
fi

# The Xcode-generated launch-performance sample exercises no product flow and
# is unstable on hosted simulators. The UI launch assertion still runs.
# The identifier must be Target/Class/Method. The earlier two-part form
# (AIEnglishAppUITests/testLaunchPerformance) matched nothing, so the sample ran every time.
xcodebuild test \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  -skip-testing:AIEnglishAppUITests/AIEnglishAppUITests/testLaunchPerformance \
  -clonedSourcePackagesDirPath "$source_packages_path" \
  -derivedDataPath "$derived_data_path"
