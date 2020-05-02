# IBM Hyper Protect SDK for iOS

This SDK implements CareKit's Remote Synchronization framework and needs to be coupled with the backend SDK (HyperProtectBackendSDK)[link] on the server side.

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
git clone --recursive git@github.com:carekit-apple/CareKitHyperProtectSDK.git
```

2. Open the `Package.swift` file to edit the SPM package.

3. Run `swift package generate-xcodeproj` to pull dependencies

### Known Issues:

Including the SDK via Swift Package Manager causes a bug in `OCKStore`'s CoreData stack. The present work around used in the sample app is to include the source files from the SDK manually.

> Note: The `OCKMongoEndpoint.swift` file in the sample app is an alias to the SPM package's source file, so changes made in one will be reflected in the other.👍
