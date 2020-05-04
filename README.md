# IBM Hyper Protect SDK for iOS

This SDK implements CareKit's Remote Synchronization API and needs to be coupled with the backend SDK (HyperProtectBackendSDK)[link] on the server side.

_Note, as this is a pre-1.0 release, it is not suitable for production use._

### Roadmap

- [ ] Logging with OSLog
- [ ] OAuth2 support with JWT
- [ ] Bi-directional Synchronization of other high level entities (Contact, CarePlan, Patient)
- [ ] Comprehensive integration tests
- [ ] Comprehensive system tests
- [ ] OpenAPI Specification template
- [ ] IBM Cloud Starter Kit support

### Getting Started

1. Clone this repo recursively

```
git clone git@github.com:carekit-apple/CareKitHyperProtectSDK.git
```

2. Open the `Package.swift` file to edit the SPM package.

### Known Issues:

When using the IBM Hyper Protect SDK, you must also include CareKit in your app via SPM. Including CareKit using the traditional subproject approach can cause runtime errors in the CoreData stack.
