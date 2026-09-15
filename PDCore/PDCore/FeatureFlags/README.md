# Feature Flags

Architecture for remotely managed feature flags (Unleash) with local UserDefaults caching.

> **Not to be confused with** `ProtonCoreFeatureFlags.FeatureFlagsRepository` — that is Proton Core's separate flag system used for account-level flags (e.g. dynamic plans). Proton Drive's Unleash flags live in this module.

## Module layout

```
PDClient/FeatureFlags/
├── Domain/ExternalFeatureFlag.swift          # enum (Unleash names)
├── Resource/UnleashFeatureFlagsResource.swift
└── Debug/…                                   # UI-test overrides

PDCore/FeatureFlags/
├── Domain/
│   ├── DriveFeatureFlagsProvider.swift        # remote → cache orchestrator
│   ├── FeatureFlagCache.swift                # local cache protocol
│   └── PhotosUploadDisabledFeatureFlagStore.swift
├── Resource/
│   ├── PersistedFeatureFlag.swift            # @propertyWrapper → UserDefaults
│   ├── FeatureFlagCatalog.swift            # all flags + cleanup
│   ├── FeatureFlagCache+LocalSettings.swift
│   └── Legacy/                               # pre-Unleash ratingIOSDrive
└── Injection/FeatureFlagSynchronizerFactory.swift

PDCoreIOS/FeatureFlags/
└── Application/FeatureFlagsController.swift  # composed app gates
```

## Layer responsibilities

| Layer | Type | Role |
|-------|------|------|
| **Source** (PDClient) | `ExternalFeatureFlagsResource` | Fetches from Unleash |
| **Synchronizer** (Domain) | `FeatureFlagSynchronizer` | Starts sources, mirrors remote values into cache, publishes updates |
| **Cache** (Domain) | `FeatureFlagCache` | Read/write persisted flag values |
| **Catalog** (Resource) | `FeatureFlagCatalog` | Declares every flag, owns cleanup lists |
| **Persisted flag** (Resource) | `@PersistedFeatureFlag` | One UserDefaults key per flag |
| **Controller** (PDCoreIOS) | `FeatureFlagsController` | Composes cache values + killswitches + build type |

One-line flow:

> **Source** fetches remotely → **Synchronizer** copies into **Cache** → **Catalog** / **PersistedFeatureFlag** write UserDefaults → **Controller** interprets for the app.

## Startup

Wired in `Tower`:

```
FeatureFlagSynchronizerFactory().makeSynchronizer(cache: localSettings)
  → starts Unleash + legacy polling
  → on update: for each ExternalFeatureFlag → cache.setFeatureValue(...)
  → updatePublisher fires → FeatureFlagsController re-evaluates
```

Access via `tower.featureFlagSync`.

## Reading flags (two APIs)

| API | When to use |
|-----|-------------|
| `tower.featureFlagSync.isEnabled(flag:)` | Raw cached remote value (SDK, macOS services, PDCore) |
| `featureFlagsController.hasSharing` etc. | Composed logic with killswitches and build type (iOS UI) |

`FeatureFlagsController` is wired with `featureFlagCache: localSettings` and `featureFlagUpdatePublishing: tower.featureFlagSync`.

## Persistence stack

1. `@PersistedFeatureFlag` — property wrapper for one UserDefaults key (+ optional payload).
2. `FeatureFlagCatalog` — declares all flags, registers storages in `configure(with:)`, handles `cleanUp(_:)`.
3. `LocalSettings` conforms to `FeatureFlagCache` and owns `featureFlagCatalog`.
4. `LocalSettings` also mirrors some flags as `@objc dynamic` for KVO (legacy); new code should use `FeatureFlagCache` or `FeatureFlagsController`.

## Adding a new flag

1. Add case to `ExternalFeatureFlag` in PDClient (`rawValue` = Unleash name).
2. Add `@PersistedFeatureFlag` property in `FeatureFlagCatalog`.
3. Add to `flagsCleanUpCatalog` if cleared on sign-out / cache reset.
4. If variant payload: extend `ExternalFeatureFlag.hasPayload` in PDClient.
5. Choose consumer:
   - Raw flag → `tower.featureFlagSync.isEnabled(flag:)`
   - Composed gate → property on `FeatureFlagsController`
6. Optional: KVO forwarding property on `LocalSettings` (legacy only).

## Name history (refactor)

| Old | New |
|-----|-----|
| `FeatureFlagsRepository` | `DriveFeatureFlagsProvider` |
| `ExternalFeatureFlagsRepository` | `DefaultDriveFeatureFlagsProvider` |
| `ExternalFeatureFlagsStore` | `FeatureFlagCache` |
| `FeatureFlagsSettings` | `FeatureFlagCatalog` |
| `FeatureFlagStorage` | `PersistedFeatureFlag` |
| `FeatureFlagRegistry` | nested in `FeatureFlagCatalog` |
| `tower.featureFlags` | `tower.featureFlagSync` |

## Tests

- `PDCoreUnitTests/FeatureFlags/Domain/FeatureFlagSynchronizerTests.swift`
- `PDCoreUnitTests/FeatureFlags/Resource/FeatureFlagCatalogTests.swift`
- `PDCoreIOSUnitTests/FeatureFlags/Application/FeatureFlagsControllerTests.swift`
