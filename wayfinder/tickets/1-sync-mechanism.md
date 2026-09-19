## Question

Should the Apple Watch app and iOS app communicate purely through WatchConnectivity (Bluetooth/local) or should they sync via a remote database (CloudKit/Firebase)?

Labels: wayfinder:grilling
Status: closed

## Resolution

We will use **CloudKit + SwiftData**. This provides automatic syncing between the Apple Watch (Standalone) and iOS app via the user's iCloud account, without requiring custom backend servers or login systems.
