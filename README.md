# CareKitHyperProtectSDK

This repo is a work in progress.

### Getting Started
1. Clone this repo recursively
```
git clone --recursive git@github.com:carekit-apple/CareKitHyperProtectSDK.git
```

2. Open the `Package.swift` file to edit the SPM package.

3. Open `CareSync/CareSync.xcodeproj` to edit or run the sample app
    1. Setup a mongoDB instance somewhere (I've been using Docker locally, for the meantime)
    3. Modify `AppDelegate.swift` to point to a mongodb instance
    4. Change `.inMemory` to `.onDisk` if you want the local database to persist between launches
    5. Tap the "Sync" button in the top right hand corner of the app to trigger synchronization

### Known Issues: 
Including the SDK via Swift Package Manager causes a bug in `OCKStore`'s CoreData stack. The present work around used in the sample app is to include the source files from the SDK manually. 
> Note: The `OCKMongoEndpoint.swift` file in the sample app is an alias to the SPM package's source file, so changes made in one will be reflected in the other.👍
