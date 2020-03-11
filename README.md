# CareKitHyperProtectSDK

This repo is a work in progress.

### Getting Started
1. Clone this repo recursively
```
git clone --recursive git@github.com:carekit-apple/CareKitHyperProtectSDK.git
```

2. Open the `Package.swift` file to edit the SPM package.

3. Open `CareSync/CareSync.xcodeproj` to edit or run the sample app
  - Modify `AppDelegate.swift` to point to a mongodb instance

### Known Issues: 
Including the SDK via Swift Package Manager causes a bug in `OCKStore`'s CoreData stack. The present work around used in the sample app is to include the source files from the SDK manually. 
> Note: The `OCKMongoEndpoint.swift` file in the sample app is an alias to the SPM package's source file, so changes made in one will be reflected in the other.👍
