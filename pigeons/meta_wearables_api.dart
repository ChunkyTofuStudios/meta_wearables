import 'package:pigeon/pigeon.dart';

// After modifying this file run:
// dart run pigeon --input pigeons/meta_wearables_api.dart && dart format .

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'meta_wearables',
    dartOut: 'lib/src/generated/platform_bindings.g.dart',
    swiftOut: 'ios/Classes/Generated/FlutterBindings.g.swift',
    kotlinOut:
        'android/src/main/kotlin/com/chunkytofustudios/meta_wearables/generated/FlutterBindings.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.chunkytofustudios.meta_wearables.generated',
    ),
  ),
)
/// Permissions that can be requested.
enum Permission { camera }

enum PermissionStatus {
  granted,
  denied,

  /// Android-only: wraps PermissionStatus.Error
  error,
}

class PermissionResult {
  PermissionStatus status;
  String? message;

  PermissionResult({required this.status, this.message});
}

/// Registration states per official docs (Android/iOS).
enum RegistrationState {
  unavailable,
  available,
  registering,
  registered,
  unregistering,
}

class RegistrationUpdate {
  RegistrationState state;
  String? errorCode;
  String? description;

  RegistrationUpdate({required this.state, this.errorCode, this.description});
}

enum VideoQuality { low, medium, high }

class StreamConfig {
  VideoQuality quality;
  int frameRate;

  StreamConfig({required this.quality, required this.frameRate});
}

/// Combined stream states across Android (STARTING/STARTED/STREAMING/STOPPING/STOPPED/CLOSED)
/// and iOS (waitingForDevice/starting/streaming/paused/stopping/stopped).
enum StreamState {
  waitingForDevice,
  starting,
  started,
  streaming,
  stopping,
  stopped,
  paused,
  closed,
}

class VideoFrameData {
  Uint8List data;
  int width;
  int height;

  VideoFrameData({
    required this.data,
    required this.width,
    required this.height,
  });
}

class PhotoData {
  Uint8List data;
  String format;

  PhotoData({required this.data, required this.format});
}

class ErrorInfo {
  String code;
  String message;

  ErrorInfo({required this.code, required this.message});
}

@HostApi()
abstract class WearablesHostApi {
  void initialize();

  @async
  PermissionResult checkPermission(Permission permission);

  @async
  PermissionResult requestPermission(Permission permission);

  @async
  RegistrationUpdate getRegistrationState();

  @async
  void startRegistration();

  @async
  void startUnregistration();

  @async
  void startStream(StreamConfig config);

  void stopStream();

  void capturePhoto();
}

@FlutterApi()
abstract class WearablesFlutterApi {
  void onRegistrationStateChanged(RegistrationUpdate update);

  void onStreamStateChanged(StreamState state);

  void onVideoFrame(VideoFrameData frame);

  void onPhotoCaptured(PhotoData photo);

  void onError(ErrorInfo error);
}
