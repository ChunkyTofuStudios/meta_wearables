import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'meta_wearables_platform_interface.dart';

/// An implementation of [MetaWearablesPlatform] that uses method channels.
class MethodChannelMetaWearables extends MetaWearablesPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('meta_wearables');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
