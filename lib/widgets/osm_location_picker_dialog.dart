import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetupLocationResult {
  final String name;
  final double latitude;
  final double longitude;

  const MeetupLocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toPayload() => {
        'location_name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  Uri get googleMapsUri => Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
}

class OsmLocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String initialName;

  const OsmLocationPickerDialog({
    super.key,
    this.initialLat = 19.0600,
    this.initialLng = 72.8338,
    this.initialName = 'Starbucks Coffee, Bandra West',
  });

  @override
  State<OsmLocationPickerDialog> createState() => _OsmLocationPickerDialogState();
}

class _OsmLocationPickerDialogState extends State<OsmLocationPickerDialog> {
  late final MapController _mapController;
  late final TextEditingController _nameController;
  late LatLng _currentCenter;
  double _currentZoom = 15.0;

  static const List<({String name, double lat, double lng, String tag})> _presets = [
    (
      name: 'Starbucks Coffee, Bandra West',
      lat: 19.0600,
      lng: 72.8338,
      tag: 'Verified Cafe',
    ),
    (
      name: 'Blue Tokai Roasters, Bandra',
      lat: 19.0558,
      lng: 72.8290,
      tag: 'Coworking Cafe',
    ),
    (
      name: 'Phoenix Palladium, Lower Parel',
      lat: 18.9950,
      lng: 72.8250,
      tag: 'Public Mall',
    ),
    (
      name: 'Marine Drive Promenade',
      lat: 18.9438,
      lng: 72.8232,
      tag: 'Public Walk',
    ),
    (
      name: 'Bandra Bandstand Seafront',
      lat: 19.0435,
      lng: 72.8193,
      tag: 'Open Seafront',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _moveTo(LatLng target, String name) {
    setState(() {
      _currentCenter = target;
      _nameController.text = name;
    });
    _mapController.move(target, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Share Meetup Pin'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            FilledButton.icon(
              key: const Key('osm_confirm_location_button'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                final name = _nameController.text.trim().isNotEmpty
                    ? _nameController.text.trim()
                    : 'Meetup Location (${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)})';
                Navigator.of(context).pop(
                  MeetupLocationResult(
                    name: name,
                    latitude: _currentCenter.latitude,
                    longitude: _currentCenter.longitude,
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Share Pin'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Safe Presets Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 15, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Safe Public Venues:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _presets.map((preset) {
                        final isSelected = (_currentCenter.latitude - preset.lat).abs() < 0.0005 &&
                            (_currentCenter.longitude - preset.lng).abs() < 0.0005;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            avatar: Icon(
                              Icons.location_on,
                              size: 16,
                              color: isSelected ? cs.onPrimary : cs.primary,
                            ),
                            label: Text(preset.name.split(',').first),
                            onSelected: (_) => _moveTo(LatLng(preset.lat, preset.lng), preset.name),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Map Area with Center Pin Overlay
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    key: const Key('osm_flutter_map'),
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCenter,
                      initialZoom: _currentZoom,
                      minZoom: 4,
                      maxZoom: 19,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture) {
                          _currentCenter = pos.center;
                          _currentZoom = pos.zoom;
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.friendify.app',
                        maxZoom: 19,
                      ),
                    ],
                  ),

                  // Fixed Center Marker Pin
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Text(
                            'Meetup Pin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_pin,
                          size: 44,
                          color: Colors.redAccent,
                        ),
                        Container(
                          width: 8,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 38), // Center offset
                      ],
                    ),
                  ),

                  // Zoom & Recenter Controls
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'osm_zoom_in',
                          onPressed: () {
                            _currentZoom = (_currentZoom + 1).clamp(4.0, 19.0);
                            _mapController.move(_currentCenter, _currentZoom);
                          },
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'osm_zoom_out',
                          onPressed: () {
                            _currentZoom = (_currentZoom - 1).clamp(4.0, 19.0);
                            _mapController.move(_currentCenter, _currentZoom);
                          },
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'osm_recenter',
                          backgroundColor: cs.primaryContainer,
                          onPressed: () => _moveTo(const LatLng(19.0600, 72.8338), 'Starbucks Coffee, Bandra West'),
                          child: const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),

                  // OpenStreetMap Attribution Banner
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Location Details & Input
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('osm_location_name_field'),
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Venue / Spot Name',
                        prefixIcon: const Icon(Icons.place_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _nameController.clear(),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'GPS: ${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)} (WGS84)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${_currentCenter.latitude},${_currentCenter.longitude}',
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Preview in Google Maps', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
