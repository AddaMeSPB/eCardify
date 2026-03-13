fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios certs

```sh
[bundle exec] fastlane ios certs
```

Sync code signing certificates and profiles

### ios regen_profile

```sh
[bundle exec] fastlane ios regen_profile
```

Force regenerate provisioning profile (e.g. after adding capabilities)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate App Store screenshots (swift-snapshot-testing)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots only to App Store Connect

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata only to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
