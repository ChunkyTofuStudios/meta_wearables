import 'package:pigeon/pigeon.dart';

enum Permission { camera }

enum PermissionStatus { granted, denied, error }

class PermissionResult {
  PermissionStatus status;
  String? message;

  PermissionResult({required this.status, this.message});
}

enum RegistrationState {
  registered,
  registering,
  unregistered,
  unregistering,
  unavailable,
  error,
}

class RegistrationUpdate {
  RegistrationState state;
  String? description;

  RegistrationUpdate({required this.state, this.description});
}

enum VideoQuality { low, medium, high }

class StreamConfig {
  VideoQuality quality;
  int frameRate;

  StreamConfig({required this.quality, required this.frameRate});
}

enum StreamState {
  stopped,
  waitingForDevice,
  starting,
  streaming,
  stopping,
  paused,
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

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'meta_wearables',
    dartOut: 'lib/src/pigeons/wearables.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/chunkytofustudios/meta_wearables/meta_wearables/Pigeon.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.chunkytofustudios.meta_wearables.meta_wearables',
    ),
    swiftOut: 'ios/Classes/Pigeon.swift',
    swiftOptions: SwiftOptions(),
  ),
)
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
