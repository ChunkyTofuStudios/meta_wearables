# meta_wearables

Flutter wrapper for the Meta Wearables Device Access Toolkit (DAT) for iOS and Android.

This plugin exposes the core Meta APIs via Pigeon:
- SDK initialization
- Registration / unregistration with the Meta AI app
- Permission checks & requests for wearable features (camera)
- Video streaming (frames + session state)
- Photo capture during a stream

> Docs: https://wearables.developer.meta.com/docs/getting-started-toolkit/

## Usage

```dart
import 'package:meta_wearables/meta_wearables.dart';

final wearables = MetaWearables.instance;

await wearables.initialize();
await wearables.startRegistration();

final perm = await wearables.requestPermission(Permission.camera);

if (perm.status == PermissionStatus.granted) {
  await wearables.startStream(quality: VideoQuality.medium, frameRate: 24);
  wearables.videoFrames.listen((frame) {
    // frame.data contains the raw bytes; frame.width / frame.height describe the frame.
  });
}
```

Streams:
- `registrationUpdates` – registration state changes
- `streamStates` – session state updates
- `videoFrames` – raw frame bytes + dimensions
- `photos` – captured photo bytes + format
- `errors` – error callbacks from native

## Android setup

1) Provide a GitHub token for the Meta Maven repo (GitHub Packages):
   - Set `GITHUB_TOKEN` (or `META_WEARABLES_GH_TOKEN`) in your environment/Gradle properties.

2) App-level `AndroidManifest.xml` must include:
```xml
<meta-data
  android:name="com.meta.wearable.mwdat.APPLICATION_ID"
  android:value="your_app_id_from_wearables_developer_center" />
<!-- Optional: disable analytics -->
<meta-data
  android:name="com.meta.wearable.mwdat.ANALYTICS_OPT_OUT"
  android:value="true" />
```

3) Ensure required Android permissions are declared (Bluetooth/Bluetooth Connect/Internet + any camera/microphone permissions your experience needs).

The plugin pulls:
```
com.meta.wearable:mwdat-core:0.2.1
com.meta.wearable:mwdat-camera:0.2.1
```

## iOS setup

The Meta SDK is distributed as a Swift Package. Add it to your Runner app target:

1) In Xcode: **File > Add Package Dependencies…**  
   URL: `https://github.com/facebook/meta-wearables-dat-ios`  
   Version: `0.2.1`

2) Info.plist (optional analytics opt-out):
```xml
<key>MWDAT</key>
<dict>
  <key>Analytics</key>
  <dict>
    <key>OptOut</key>
    <true/>
  </dict>
</dict>
```

3) The plugin listens for registration/permission callbacks by handling `application:openURL:` and forwarding URLs with the `metaWearablesAction` query param to the SDK.

## Notes / roadmap
- Example app not wired up yet.
- iOS build requires the Swift Package to be added as described above; without it, the plugin stubs will surface an error via `errors` stream.
