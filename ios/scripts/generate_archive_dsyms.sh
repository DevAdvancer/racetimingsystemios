#!/bin/sh
set -eu

# App Store Connect expects dSYM bundles for embedded binary frameworks.
# Some vendored/native-asset frameworks do not ship dSYMs, so create matching
# bundles during archive validation from the embedded framework binaries.
if [ "${ACTION:-}" != "install" ]; then
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  exit 0
fi

frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "${DWARF_DSYM_FOLDER_PATH}"

generate_framework_dsym() {
  framework_name="$1"
  binary_name="$2"
  binary_path="${frameworks_dir}/${framework_name}.framework/${binary_name}"
  dsym_path="${DWARF_DSYM_FOLDER_PATH}/${framework_name}.framework.dSYM"

  if [ ! -f "${binary_path}" ]; then
    return 0
  fi

  echo "Generating dSYM for ${framework_name}.framework"
  /usr/bin/dsymutil "${binary_path}" -o "${dsym_path}"
}

generate_framework_dsym "BRLMPrinterKit" "BRLMPrinterKit"
generate_framework_dsym "sqlite3" "sqlite3"
