# unleash-proxy-client-swift

The unleash-proxy-client-swift makes it easy for native applications and other swift platforms to connect to the unleash proxy. The proxy will evaluate a feature toggle for a given [context](https://docs.getunleash.io/docs/user_guide/unleash_context) and return a list of feature flags relevant for the provided context.

The unleash-proxy-client-swift will then cache these toggles in a map in memory and refresh the configuration at a configurable interval, making queries against the toggle configuration extremely fast.

## Requirements

- MacOS: 12.15
- iOS: 12

## Installation

Follow the following steps in order to install the unleash-proxy-client-swift:

1. In your Xcode project go to File -> Swift Packages -> Add Package Dependency
2. Supply the link to this repository
3. Set the appropriate package constraints (typically up to next major version)
4. Let Xcode find and install the necessary packages

Once you're done, you should see SwiftEventBus and UnleashProxyClientSwift listed as dependencies in the file explorer of your project.

## Usage

In order to get started you need to import and instantiate the unleash client:

### iOS >= 13

```swift
import SwiftUI
import UnleashProxyClientSwift

// Setup Unleash in the context where it makes most sense

var unleash = UnleashProxyClientSwift.UnleashClient(unleashUrl: "https://<unleash-instance>/api/frontend", clientKey: "<client-side-api-token>", refreshInterval: 15, appName: "test", context: ["userId": "c3b155b0-5ebe-4a20-8386-e0cab160051e"])

unleash.start()
```

### iOS >= 12

```swift
import SwiftUI
import UnleashProxyClientSwift

// Setup Unleash in the context where it makes most sense

var unleash = UnleashProxyClientSwift.UnleashClientBase(unleashUrl: "https://<unleash-instance>/api/frontend", clientKey: "<client-side-api-token>", refreshInterval: 15, appName: "test", context: ["userId": "c3b155b0-5ebe-4a20-8386-e0cab160051e"])

unleash.start()
```

In the example above we import the UnleashProxyClientSwift and instantiate the client. You need to provide the following parameters:

- `unleashUrl`: the full url to either the [Unleash front-end API](https://docs.getunleash.io/reference/front-end-api) OR an [Unleash proxy](https://docs.getunleash.io/reference/unleash-proxy) [String]
- `clientKey`: either an [client-side API token](https://docs.getunleash.io/reference/api-tokens-and-client-keys#front-end-tokens) if you use the front-end API ([how](https://docs.getunleash.io/how-to/how-to-create-api-tokens 'how do I create API tokens?')) or a [proxy client key](https://docs.getunleash.io/reference/api-tokens-and-client-keys#proxy-client-keys) if you use the proxy [String]
- `refreshInterval`: the polling interval in seconds [Int]. Set to `0`to only poll once and disable a periodic polling
- `appName`: the application name identifier [String]
- `context`: the context parameters except from `appName` and `environment` which should be specified explicitly in the init [[String: String]]

Running `unleash.start()` will make the first request against the proxy and retrieve the feature toggle configuration, and set up the polling interval in the background.

NOTE: While waiting to boot up the configuration may not be available, which means that asking for a feature toggle may result in a false if the configuration has not loaded. In the event that you need to be certain that the configuration is loaded we emit an event you can subscribe to, once the configuration is loaded. See more in the Events section.

Once the configuration is loaded you can ask against the cache for a given feature toggle:

```swift
if unleash.isEnabled(name: "ios") {
    // do something
} else {
   // do something else
}
```

You can also set up [variants](https://docs.getunleash.io/docs/advanced/toggle_variants) and use them in a similar fashion:

```swift
var variant = unleash.getVariant(name: "ios")
if variant.enabled {
    // do something
} else {
   // do something else
}
```

### Update context

In order to update the context you can use the following method:

```swift
var context: [String: String] = [:]
context["userId"] = "c3b155b0-5ebe-4a20-8386-e0cab160051e"
unleash.updateContext(context: context)
```

This will stop and start the polling interval in order to renew polling with new context values.

You can use any of the [predefined fields](https://docs.getunleash.io/reference/unleash-context#structure). If you need to support
[custom properties](https://docs.getunleash.io/reference/unleash-context#the-properties-field) pass them as the second argument:

```swift
var context: [String: String] = [:]
context["userId"] = "c3b155b0-5ebe-4a20-8386-e0cab160051e"
var properties: [String: String] = [:]
properties["customKey"] = "customValue";
unleash.updateContext(context: context, properties: properties)
```


## Events

The proxy client emits events that you can subscribe to. The following events are available:

- "ready"
- "update"
- "sent" (metrics sent)
- "error" (metrics sending error)

Usage them in the following manner:

```swift
func handleReady() {
    // do this when unleash is ready
}

unleash.subscribe(name: "ready", callback: handleReady)

func handleUpdate() {
    // do this when unleash is updated
}

unleash.subscribe(name: "update", callback: handleUpdate)
```

The ready event is fired once the client has received it's first set of feature toggles and cached it in memory. Every subsequent event will be an update event that is triggered if there is a change in the feature toggle configuration.

## Releasing

Note: To release the package you'll need to have [CocoaPods](https://cocoapods.org/) installed.

First, you'll need to add a tag. Releasing the tag is enough for the Swift package manager, but it's polite to also ensure CocoaPods users can also consume the code.

```sh
git tag -a 0.0.4 -m "v0.0.4"
```

Please make sure that that tag is pushed to remote.

The next few commands assume that you have CocoaPods installed and available on your shell.

First, validate your session with cocoapods with the following command:

```sh
pod trunk register <email> "Your name"
```

The email that owns this package is the general unleash team email. Cocoapods will send a link to this email, click it to validate your shell session.

Bump the version number of the package, you can find this in `UnleashProxyClientSwift.podspec`, we use SemVer for this project. Once that's committed and merged to main:

Linting the podspec is always a good idea:

```sh
pod spec lint UnleashProxyClientSwift.podspec
```

Once that succeeds, you can do the actual release:

```sh
pod trunk push UnleashProxyClientSwift.podspec --allow-warnings
```
