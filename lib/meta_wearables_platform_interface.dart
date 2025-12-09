import 'package:meta_wearables/meta_wearables_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class MetaWearablesPlatform extends PlatformInterface {
  /// Constructs a MetaWearablesPlatform.
  MetaWearablesPlatform() : super(token: _token);

  static final Object _token = Object();

  static MetaWearablesPlatform _instance = MethodChannelMetaWearables();

  /// The default instance of [MetaWearablesPlatform] to use.
  ///
  /// Defaults to [MethodChannelMetaWearables].
  static MetaWearablesPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MetaWearablesPlatform] when
  /// they register themselves.
  static set instance(MetaWearablesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
