import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/maps_launcher.dart';
import 'package:planfit/features/settings/application/app_settings.dart';

void main() {
  group('buildMapsSearchUri', () {
    test('MapsAppPreference.system resolves to Apple Maps on iOS', () {
      final uri = buildMapsSearchUri(
        query: 'Coffee shop',
        preference: MapsAppPreference.system,
        isIOS: true,
      );
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['q'], 'Coffee shop');
    });

    test(
      'MapsAppPreference.system resolves to Google Maps everywhere else',
      () {
        final uri = buildMapsSearchUri(
          query: 'Coffee shop',
          preference: MapsAppPreference.system,
          isIOS: false,
        );
        expect(uri.host, 'www.google.com');
        expect(uri.path, '/maps/search/');
        expect(uri.queryParameters['query'], 'Coffee shop');
      },
    );

    test('an explicit MapsAppPreference.appleMaps wins regardless of platform '
        '— even on Android, since it\'s still a plain https link the OS can '
        'fall back to opening in a browser', () {
      final uri = buildMapsSearchUri(
        query: 'Coffee shop',
        preference: MapsAppPreference.appleMaps,
        isIOS: false,
      );
      expect(uri.host, 'maps.apple.com');
    });

    test('an explicit MapsAppPreference.googleMaps wins regardless of '
        'platform — even on iOS', () {
      final uri = buildMapsSearchUri(
        query: 'Coffee shop',
        preference: MapsAppPreference.googleMaps,
        isIOS: true,
      );
      expect(uri.host, 'www.google.com');
    });
  });
}
