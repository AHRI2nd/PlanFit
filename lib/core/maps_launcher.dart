import '../features/settings/application/app_settings.dart';

/// The map-search URL `EventEditorSheet`/`EventPreviewSheet`'s own "지도에서
/// 열기"/[eventOpenInMaps] action opens for [query], given the user's
/// [MapsAppPreference] and (only consulted for [MapsAppPreference.system])
/// [isIOS].
///
/// Both real choices resolve to a plain `https://` universal link — no
/// custom URL scheme, so neither needs an iOS `LSApplicationQueriesSchemes`/
/// Android `<queries>` manifest entry to open the right app when it's
/// installed (falling back to a browser otherwise). [isIOS] is a plain
/// parameter rather than this function reading `dart:io`'s `Platform`
/// itself, purely so both branches of [MapsAppPreference.system] stay
/// directly unit-testable without needing a real iOS/Android host to run
/// the test on — this app has no platform-mocking seam, and every other
/// `Platform.isIOS` call site in the app is just read at its own call site
/// the same way this function's own caller does.
Uri buildMapsSearchUri({
  required String query,
  required MapsAppPreference preference,
  required bool isIOS,
}) {
  final useAppleMaps = switch (preference) {
    MapsAppPreference.appleMaps => true,
    MapsAppPreference.googleMaps => false,
    MapsAppPreference.system => isIOS,
  };
  return useAppleMaps
      ? Uri.https('maps.apple.com', '/', {'q': query})
      : Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': query,
        });
}
