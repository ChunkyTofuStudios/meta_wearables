import 'dart:async';

import 'package:meta_wearables/src/generated/platform_bindings.g.dart';

/// High-level Flutter wrapper around the Meta Wearables Device Access Toolkit.
class MetaWearables implements WearablesFlutterApi {
  MetaWearables._() {
    WearablesFlutterApi.setUp(this);
  }

  static final MetaWearables instance = MetaWearables._();
  final WearablesHostApi _host = WearablesHostApi();

  final _registrationController =
      StreamController<RegistrationUpdate>.broadcast();
  final _streamStateController = StreamController<StreamState>.broadcast();
  final _videoFrameController = StreamController<VideoFrameData>.broadcast();
  final _photoController = StreamController<PhotoData>.broadcast();
  final _errorController = StreamController<ErrorInfo>.broadcast();

  /// Initializes the native SDKs. Must be called before any other API.
  Future<void> initialize() => _host.initialize();

  /// Returns the current registration state.
  Future<RegistrationUpdate> getRegistrationState() =>
      _host.getRegistrationState();

  /// Stream of registration state changes.
  Stream<RegistrationUpdate> get registrationUpdates =>
      _registrationController.stream;

  /// Starts the registration flow with the Meta AI app.
  Future<void> startRegistration() => _host.startRegistration();

  /// Starts unregistration flow.
  Future<void> startUnregistration() => _host.startUnregistration();

  /// Checks current wearable permission (e.g., camera).
  Future<PermissionResult> checkPermission(Permission permission) =>
      _host.checkPermission(permission);

  /// Requests wearable permission via Meta AI app.
  Future<PermissionResult> requestPermission(Permission permission) =>
      _host.requestPermission(permission);

  /// Starts streaming with the given config.
  Future<void> startStream({
    VideoQuality quality = VideoQuality.medium,
    int frameRate = 30,
  }) => _host.startStream(StreamConfig(quality: quality, frameRate: frameRate));

  /// Stops the current stream session.
  Future<void> stopStream() => _host.stopStream();

  /// Captures a photo during an active stream.
  Future<void> capturePhoto() => _host.capturePhoto();

  Stream<StreamState> get streamStates => _streamStateController.stream;
  Stream<VideoFrameData> get videoFrames => _videoFrameController.stream;
  Stream<PhotoData> get photos => _photoController.stream;
  Stream<ErrorInfo> get errors => _errorController.stream;

  // WearablesFlutterApi callbacks from native side
  @override
  void onRegistrationStateChanged(RegistrationUpdate update) {
    _registrationController.add(update);
  }

  @override
  void onStreamStateChanged(StreamState state) {
    _streamStateController.add(state);
  }

  @override
  void onVideoFrame(VideoFrameData frame) {
    _videoFrameController.add(frame);
  }

  @override
  void onPhotoCaptured(PhotoData photo) {
    _photoController.add(photo);
  }

  @override
  void onError(ErrorInfo error) {
    _errorController.add(error);
  }
}
