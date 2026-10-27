import 'dart:io';
import 'package:flutter/services.dart';

class JsonAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => File(key).existsSync()
      ? Future.value(ByteData.sublistView(File(key).readAsBytesSync()))
      : rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).existsSync()
      ? Future.value(File(key).readAsStringSync())
      : rootBundle.loadString(key, cache: cache);
}
