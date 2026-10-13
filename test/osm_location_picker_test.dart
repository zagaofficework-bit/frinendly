import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/widgets/osm_location_picker_dialog.dart';
import 'package:friendify/widgets/osm_map_bubble.dart';

void main() {
  group('OpenStreetMap Location Picker & Live Search Engine Tests', () {
    testWidgets('OsmLocationPickerDialog renders all interactive elements and controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsmLocationPickerDialog(
              initialLat: 19.0600,
              initialLng: 72.8338,
              initialName: 'Starbucks Coffee, Bandra West',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title & Share Pin button
      expect(find.text('Share Meetup Pin'), findsOneWidget);
      expect(find.byKey(const Key('osm_confirm_location_button')), findsOneWidget);

      // Verify Search Bar and its buttons
      expect(find.byKey(const Key('osm_search_text_field')), findsOneWidget);
      expect(find.byKey(const Key('osm_search_submit_button')), findsOneWidget);

      // Verify Safe Presets
      expect(find.text('Verified Safe Public Venues:'), findsOneWidget);
      expect(find.text('Starbucks Coffee'), findsOneWidget);
      expect(find.text('Blue Tokai Roasters'), findsOneWidget);
      expect(find.text('Phoenix Palladium'), findsOneWidget);

      // Verify Map and Controls
      expect(find.byKey(const Key('osm_flutter_map')), findsOneWidget);
      expect(find.text('Meetup Pin'), findsOneWidget);
      expect(find.byKey(const Key('osm_zoom_in')), findsOneWidget);
      expect(find.byKey(const Key('osm_zoom_out')), findsOneWidget);
      expect(find.byKey(const Key('osm_recenter')), findsOneWidget);

      // Verify Venue Input and Actions
      expect(find.byKey(const Key('osm_location_name_field')), findsOneWidget);
      expect(find.text('Starbucks Coffee, Bandra West'), findsOneWidget);
      expect(find.byKey(const Key('osm_preview_gmaps_button')), findsOneWidget);
      expect(find.textContaining('WGS84'), findsOneWidget);
    });

    testWidgets('OsmLocationPickerDialog zoom in, zoom out, and preset selection update state', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsmLocationPickerDialog(
              initialLat: 19.0600,
              initialLng: 72.8338,
              initialName: 'Starbucks Coffee, Bandra West',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Zoom In
      await tester.tap(find.byKey(const Key('osm_zoom_in')));
      await tester.pumpAndSettle();

      // Tap Zoom Out
      await tester.tap(find.byKey(const Key('osm_zoom_out')));
      await tester.pumpAndSettle();

      // Select preset chip
      await tester.tap(find.text('Phoenix Palladium'));
      await tester.pumpAndSettle();

      // Venue text field should update to Phoenix Palladium
      expect(find.text('Phoenix Palladium, Lower Parel'), findsOneWidget);

      // Clear venue text field using clear button
      expect(find.byKey(const Key('osm_clear_name_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('osm_clear_name_button')));
      await tester.pumpAndSettle();

      // Type custom name
      await tester.enterText(find.byKey(const Key('osm_location_name_field')), 'My Custom Cafe Meeting Spot');
      await tester.pumpAndSettle();
      expect(find.text('My Custom Cafe Meeting Spot'), findsOneWidget);
    });

    testWidgets('OsmLocationPickerDialog share button returns MeetupLocationResult', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MeetupLocationResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_picker_button'),
                  onPressed: () async {
                    result = await showDialog<MeetupLocationResult>(
                      context: context,
                      builder: (_) => const OsmLocationPickerDialog(
                        initialLat: 18.9950,
                        initialLng: 72.8250,
                        initialName: 'Phoenix Palladium, Lower Parel',
                      ),
                    );
                  },
                  child: const Text('Open Picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const Key('open_picker_button')));
      await tester.pumpAndSettle();

      expect(find.text('Share Meetup Pin'), findsOneWidget);

      // Tap Share Pin button
      await tester.tap(find.byKey(const Key('osm_confirm_location_button')));
      await tester.pumpAndSettle();

      // Dialog should close and return result
      expect(find.text('Share Meetup Pin'), findsNothing);
      expect(result, isNotNull);
      expect(result!.name, 'Phoenix Palladium, Lower Parel');
      expect(result!.latitude, 18.9950);
      expect(result!.longitude, 72.8250);
      expect(result!.googleMapsUri.toString(), contains('query=18.995,72.825'));
    });

    testWidgets('OsmMapBubble renders pinned location and external map action', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: OsmMapBubble(
                locationName: 'Starbucks Coffee, Bandra West',
                latitude: 19.0600,
                longitude: 72.8338,
                isMine: true,
                textColor: Colors.black87,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Starbucks Coffee, Bandra West'), findsOneWidget);
      expect(find.byKey(const Key('open_in_google_maps_button')), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.textContaining('19.0600, 72.8338'), findsOneWidget);
    });
  });
}
