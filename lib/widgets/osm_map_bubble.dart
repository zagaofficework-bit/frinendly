import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'osm_location_picker_dialog.dart';

class OsmMapBubble extends StatelessWidget {
  final String locationName;
  final double latitude;
  final double longitude;
  final bool isMine;
  final Color textColor;

  const OsmMapBubble({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.isMine,
    required this.textColor,
  });

  Future<void> _openInGoogleMaps(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open map: $uri')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $e')),
        );
      }
    }
  }

  void _openInteractiveMap(BuildContext context) {
    showDialog<MeetupLocationResult>(
      context: context,
      builder: (_) => OsmLocationPickerDialog(
        initialLat: latitude,
        initialLng: longitude,
        initialName: locationName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latLng = LatLng(latitude, longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini OpenStreetMap Snapshot
        InkWell(
          onTap: () => _openInteractiveMap(context),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 140,
              width: 250,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: latLng,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.friendify.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: latLng,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.redAccent,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_out_map, size: 11, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Expand', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Venue Name & Coordinates
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: isMine ? Colors.amberAccent : Colors.red, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                locationName,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'GPS: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          style: TextStyle(
            fontSize: 10,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),

        // Action Buttons Row: Google Maps Navigation Shortcut
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isMine ? Colors.black26 : Colors.black12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 12, color: textColor),
                  const SizedBox(width: 4),
                  Text(
                    'Public Meetup Point',
                    style: TextStyle(fontSize: 9.5, color: textColor),
                  ),
                ],
              ),
            ),
            InkWell(
              key: const Key('open_in_google_maps_button'),
              onTap: () => _openInGoogleMaps(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMine ? Colors.white.withValues(alpha: 0.25) : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions,
                      size: 13,
                      color: isMine ? textColor : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Google Maps',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isMine ? textColor : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
