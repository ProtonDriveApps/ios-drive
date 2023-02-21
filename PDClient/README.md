
# PDClient

Networking client for ProtonDrive APIs

## Combine version

Available for macOS 10.15 and iOS 13.0 and higher.

Usage:
```
let client = Client(credential: self.credential, service: APIService())

self.cancellable = client.getVolumes().sink(receiveCompletion: { completion in
    switch completion {
    case .finished: break
    case .failure(let serverResponse as ErrorResponse):
        // server error response
    case .failure(let error):
       // networking or client error
}, receiveValue: { volumes in
    // result here
})
```

## Completion handlers version

Intended to support platforms without Combine - older than macOS 10.15 and iOS 13.0.

Usage:
```
let client = Client(credential: self.credential, service: APIService())
client.getVolumes() { completion in
   switch completion {
   case .success(let volumes):
       // result here 
   case .failure(let serverResponse as ErrorResponse):
       // server error response
   case .failure(let error):
       // networking or client error
   }
}
```

## Tests

Tests involve interaction with BE, and all endpoints are authenticated. Authentication flow passes during `setUp()` method of each tesing class. The target depends on `PMAuthentication` package installed via Swift Package Manager. Package itself depends on `Crypto.xcframework` and some glue code - they are imported as symlinks to the objects residing under `PMCore` project directory. Be careful with those symlinks. 

Reasonably, we need a valid user on the BE and a host configuration - see `TestAuthentication.swift`.
