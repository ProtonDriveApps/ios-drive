# Proton Drive for iOS

iOS client for end-to-end encrypted cloud storage made by Proton AG. Securely backup and share your files. Open source, publicly audited, and Swiss based.

[Trust Model](TRUSTMODEL.md)

## Targets

ProtonDrive for iOS has important schemes used regularly during development:
- `ProtonDrive-iOS` - runs the main app
- `ProtonDriveFileProvider` - runs the File Provider extension
- `ProtonDriveFileProviderUI` - runs the File Provider UI extension
- `ProtonDriveShare` - runs the Share extension

For Release builds and distribution, see configs and schemes in the [root README](../README.md#xcode-project-configs-and-schemes).

## Setup

1. Have macOS up to date and install Xcode
2. Install Ruby 3+ and run `bundle install` from the repository root
3. Generate the Xcode project: `sh Scripts/xcodegen/xcodeGenerate.sh` (from the repository root; `ProtonDrive-iOS.xcodeproj` is not checked in)
4. Open `../ProtonDrive.xcworkspace`
5. Select the `ProtonDrive-iOS` scheme
6. Set your Development Team on the following targets (Debug uses automatic signing):
   - `ProtonDrive`
   - `ProtonDriveFileProvider`
   - `ProtonDriveFileProviderUI`
   - `ProtonDriveShare`
7. Build and run on an Apple Silicon simulator or device (minimum deployment target: iOS 16.0)

## Troubleshooting

For general environment cleanup (Derived Data, old simulators, and caches):
`bash Scripts/ios/cleanup_runner.sh`

## Contributions

Contributions are not accepted at the moment.

## Dependencies

All dependencies are managed by SPM.

[Acknowledgements](ProtonDrive/Acknowledgements.markdown)

## License

The code and data files in this distribution are licensed under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See <https://www.gnu.org/licenses/> for a copy of this license.

See [LICENSE](../LICENSE) file

Copyright (c) 2024 Proton AG
