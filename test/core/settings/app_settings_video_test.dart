import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/settings/app_settings.dart';

void main() {
  test('videoUploadOnMobileData defaults to false and round-trips', () {
    expect(AppSettings.defaults.videoUploadOnMobileData, isFalse);
    final on = AppSettings.defaults.copyWith(videoUploadOnMobileData: true);
    final json = on.toJson();
    expect(json['videoUploadOnMobileData'], true);
    expect(AppSettings.fromJson(json).videoUploadOnMobileData, isTrue);
  });

  test('an older blob without the key reads false', () {
    final json = AppSettings.defaults.toJson()
      ..remove('videoUploadOnMobileData');
    expect(AppSettings.fromJson(json).videoUploadOnMobileData, isFalse);
  });
}
