if [[ $CI ]]; then
  echo "Skipping linting on the CI"
  exit 0
fi

SWIFT_PACKAGE_DIR="${BUILD_DIR%Build/*}SourcePackages/artifacts"
SWIFTLINT_CMD=$(ls "$SWIFT_PACKAGE_DIR"/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/swiftlint-*/bin/swiftlint | head -n 1)

if test -f "$SWIFTLINT_CMD" 2>&1
then
    "$SWIFTLINT_CMD" --config ${PROJECT_DIR}/../.swiftlint.yml
else
    echo "warning: `swiftlint` command not found - See https://github.com/realm/SwiftLint#installation for installation instructions."
fi
