import 'meta_wearables_platform_interface.dart';

class MetaWearables {
  Future<String?> getPlatformVersion() {
    return MetaWearablesPlatform.instance.getPlatformVersion();
  }
}
