# QhristmasReader

## Overview
QhristmasReader is a fun Christmas present distribution app that replaces traditional name labels with barcodes. The app allows you to wrap presents with UUID-encoded barcodes, associate them with recipient information and photos, and distribute them at Christmas using a local network sync system.

## How It Works

### Gift Preparation (Pre-Christmas)
1. **Take Photo**: Before wrapping, take a photo of the present
2. **Generate Barcode**: Create a barcode containing a unique UUID
3. **Store in Database**: Associate the photo with the UUID and recipient(s) in the local Core Data database
4. **Wrap & Label**: Wrap the present and attach the barcode label

### Gift Distribution (Christmas Day)
1. **Host Database**: The gift giver hosts the database over the local network
2. **Family Downloads App**: Family members download and run the app
3. **Scan to Reveal**: Anyone scans a barcode to query the host app who it's for
   - Gift giver can also see the unwrapped photo
   - Recipients only see their name

## Technical Architecture

### Core Data Model
- **Gift**: Represents a wrapped present
  - `imageID`: UUID for the unwrapped photo
  - `originID`: Original UUID for tracking
  - `label`: Optional text label
  - `lastUpdated`: Timestamp for sync
  - `recipients`: Set of Recipient objects (many-to-many)
  - Photos stored as JPEG files in local storage

- **Recipient**: Represents a person who can receive gifts
  - `id`: UUID identifier
  - `originID`: Original UUID for tracking
  - `name`: Person's name
  - `lastUpdated`: Timestamp for sync
  - `gifts`: Set of Gift objects (many-to-many)

### Networking (Multipeer Connectivity)
- **Technology**: Apple's MultipeerConnectivity framework
- **Service Type**: "qhristmasreader"
- **Architecture**: Client-server model
  - Server: Gift giver hosts the database
  - Clients: Family members connect to browse/scan

### Known Issues
- **Multipeer Connectivity Stability**: With 5-7 users, the multipeer connection proved unstable
  - Frequent disconnections after a few minutes
  - Hangs with no clear error messages
  - This is the primary technical challenge limiting usability

## Project Structure
```
QhristmasReader/
├── AppDelegate.swift
├── SceneDelegate.swift
├── Coordinator/              # Navigation coordination
│   ├── GiverListCoordinator
│   ├── GiverRootCoordinator
│   ├── RootCoordinator
│   ├── RecipientCoordinator
│   └── SyncCoordinator
├── CoreData/                 # Data models
│   ├── Gift+Convenience.swift
│   ├── Recipient+Convenience.swift
│   └── ItemInfo.xcdatamodeld
├── Detail/                   # Gift detail views
├── List/                     # List views
├── QR and Photo Capture/     # Barcode scanning & photo capture
├── Recipient Flow/           # Recipient-side UI
├── Syncing/                  # Network sync engine
│   ├── LocalNetworkEngine/
│   ├── LocalNetworkEngineServer
│   ├── LocalNetworkEngineClient
│   └── SyncController
├── Onboarding/              # First-time setup
└── Utility/                 # Helper utilities
```

## Current State
- **Last Used**: Christmas 2024
- **Status**: Functional but networking is unreliable
- **Next Steps**: Consider alternative networking solutions for 2025

## Potential Improvements for 2025
- Replace MultipeerConnectivity with more stable networking (e.g., local HTTP server, Bonjour with custom protocol, CloudKit)
- Add better error handling and connection status indicators
- Implement automatic reconnection logic
- Consider offline mode with manual sync
- Add connection diagnostics and logging

## Development Notes
- iOS app written in Swift
- Uses UIKit with coordinator pattern for navigation
- Core Data for local persistence
- JPEG compression at 0.85 quality for photos
- Request timeout: 30 seconds for network operations

## External Documentation
- **Hummingbird**: https://docs.hummingbird.codes/2.0/documentation/hummingbird/gettingstarted/
  - Server-side Swift framework for HTTP servers
  - Being evaluated as replacement for MultipeerConnectivity data transport
