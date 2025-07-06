# AudioPal Widget

A SwiftUI widget that provides quick access to voice recording functionality.

## Features

- **Quick Recording Access**: Tap the widget to start recording
- **Real-time Status**: Shows recording status and duration
- **Permission Awareness**: Displays when permissions are required
- **Multiple Sizes**: Supports small and medium widget sizes

## Setup Instructions

### 1. Create Widget Extension Target

1. In Xcode, go to **File > New > Target**
2. Select **Widget Extension** under iOS
3. Name it "AudioPalWidgetExtension"
4. Make sure "Include Configuration Intent" is **unchecked**
5. **Important**: Make sure "Embed in Application" is set to your main app
6. Click **Finish**
7. **Important**: When prompted, choose "Activate" to add the target to your scheme

### 2. Configure App Groups

1. Select your main app target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **App Groups**
4. Add group: `group.testaaa.audioPal`
5. Repeat for the widget extension target

### 3. Add URL Scheme

1. Select your main app target
2. Go to **Info** tab in project settings
3. Expand **URL Types** section
4. Click **+** to add a new URL type
5. Set **URL Schemes** to: `audiopal`
6. Set **Identifier** to: `com.testaaa.audioPal`

### 4. Copy Widget Files

**Important**: The widget extension target should have its own separate files. Copy these files to your widget extension target:

- `AudioPalWidget.swift` - Main widget implementation
- `WidgetDataManager.swift` - Shared data communication

**Note**: The widget extension target will automatically create its own `@main` entry point. You don't need to manually add one.

### 5. Configure Widget Extension Target

1. Select the widget extension target
2. Go to **Info** tab
3. Set **Bundle Identifier** to: `com.testaaa.audioPal.widget`
4. Set **Display Name** to: `AudioPal`
5. Ensure **Deployment Target** matches main app

### 6. Update Main App

Add to your main app:
- `URLSchemeHandler.swift` (in main app target)
- Update `ChatViewModel` to use `WidgetDataManager`

## Widget States

### Idle State
- Shows microphone icon
- "Tap to Record" text
- Blue color scheme

### Recording State
- Animated red recording indicator
- "Recording..." text
- Recording duration display
- Red color scheme

### Permission Required State
- Shows permission warning
- Orange color scheme
- "Permissions Required" text

## Data Communication

The widget communicates with the main app through:
- **App Groups**: Shared UserDefaults
- **URL Schemes**: Deep linking for actions
- **WidgetKit**: Timeline updates

## Customization

### Colors
- Primary: Blue (`Color.blue`)
- Recording: Red (`Color.red`)
- Warning: Orange (`Color.orange`)

### Update Frequency
- Idle: Every 30 seconds
- Recording: Every 5 seconds

### Supported Sizes
- Small (systemSmall)
- Medium (systemMedium)

## Troubleshooting

### Widget Not Updating
1. Check App Groups configuration
2. Verify `WidgetDataManager` is updating data
3. Call `WidgetCenter.shared.reloadAllTimelines()`

### URL Scheme Not Working
1. Verify URL scheme in Info.plist
2. Check `URLSchemeHandler` implementation
3. Test with `URLScheme.recordURL()`

### Permissions Not Syncing
1. Ensure both targets have same App Group
2. Check `WidgetDataManager` permissions methods
3. Verify UserDefaults suite name

## Usage Example

```swift
// In ChatViewModel
func startRecording(completion: @escaping (String) -> Void) {
    // ... existing code ...
    
    // Update widget
    WidgetDataManager.shared.updateRecordingStatus(isRecording: true)
}

func stopRecording() {
    // ... existing code ...
    
    // Update widget
    WidgetDataManager.shared.updateRecordingStatus(isRecording: false)
}
```

## Notes

- Widget updates are limited by iOS system constraints
- Background app refresh may affect update frequency
- Widget interactions are limited to URL scheme deep links
- Consider battery impact of frequent updates 