import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

class OsmSearchResult {
  final String displayName;
  final String name;
  final double latitude;
  final double longitude;
  final String? type;
  final String? category;

  const OsmSearchResult({
    required this.displayName,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type,
    this.category,
  });

  factory OsmSearchResult.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;
    final displayName = json['display_name'] as String? ?? 'Unknown Place';
    final rawName = json['name'] as String?;
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : displayName.split(',').first.trim();

    return OsmSearchResult(
      displayName: displayName,
      name: name,
      latitude: lat,
      longitude: lon,
      type: json['type'] as String?,
      category: json['class'] as String?,
    );
  }
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
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  late LatLng _currentCenter;
  double _currentZoom = 15.0;

  Timer? _debounceTimer;
  bool _isSearching = false;
  bool _isLocating = false;
  String? _searchError;
  List<OsmSearchResult> _searchResults = [];

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
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _moveTo(LatLng target, String name) {
    setState(() {
      _currentCenter = target;
      _nameController.text = name;
    });
    _mapController.move(target, _currentZoom);
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=8',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Friendify-App/1.0 (contact: info@friendify.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final results = data
            .map((item) => OsmSearchResult.fromJson(item as Map<String, dynamic>))
            .where((r) => r.latitude != 0.0 && r.longitude != 0.0)
            .toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
            _searchError = results.isEmpty ? 'No results found on OpenStreetMap' : null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
            _searchError = 'Search service error (${response.statusCode})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = 'Network error or timeout. Please check your connection.';
        });
      }
    }
  }

  void _selectSearchResult(OsmSearchResult result) {
    final target = LatLng(result.latitude, result.longitude);
    _currentZoom = 16.0;
    _moveTo(target, result.name.isNotEmpty ? result.name : result.displayName);

    setState(() {
      _searchResults = [];
      _isSearching = false;
      _searchError = null;
      _searchController.text = result.name;
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _showLocationServiceDisabledDialog() async {
    if (!mounted) return;
    if (!kIsWeb) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Turn On Location'),
            ],
          ),
          content: const Text(
            'GPS / Location Services are currently turned off. Please enable device location to automatically find and pin your current spot.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Open Settings'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await Geolocator.openLocationSettings();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location access in your browser to relocate your pin.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showPermissionDeniedForeverDialog() async {
    if (!mounted) return;
    if (!kIsWeb) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_person_outlined, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Location Permission'),
            ],
          ),
          content: const Text(
            'Location permission is permanently denied for Friendify. Please enable location permissions in App Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('App Settings'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await Geolocator.openAppSettings();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission was permanently blocked. Please allow location in browser settings.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _relocateToMyPosition() async {
    setState(() {
      _isLocating = true;
    });

    try {
      // 1. Check and request location permission first so Android prompts the user
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission is needed to relocate to your position.'),
                action: SnackBarAction(
                  label: 'Grant',
                  textColor: Colors.white,
                  onPressed: _relocateToMyPosition,
                ),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await _showPermissionDeniedForeverDialog();
        return;
      }

      // 2. Check if device location services (GPS) are enabled
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true; // Safe fallback if platform check throws
      }

      if (!serviceEnabled) {
        await _showLocationServiceDisabledDialog();
        return;
      }

      // 3. Acquire live GPS coordinates
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        if (!kIsWeb) {
          try {
            pos = await Geolocator.getLastKnownPosition();
          } catch (_) {}
        }
      }

      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not obtain current GPS position. You can drag the pin or search your spot above.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final target = LatLng(pos.latitude, pos.longitude);
      _currentZoom = 16.0;
      final defaultName = 'My Live GPS Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
      _moveTo(target, defaultName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relocated to: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }

      // 4. Reverse geocode asynchronously via Nominatim
      _reverseGeocode(pos.latitude, pos.longitude);
    } on LocationServiceDisabledException {
      await _showLocationServiceDisabledDialog();
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission was denied.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS plugin requires app restart. Please stop and run "flutter run".'),
            backgroundColor: Colors.deepOrange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location unavailable: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Friendify-App/1.0 (contact: info@friendify.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawName = data['name'] as String?;
        final displayName = data['display_name'] as String?;

        String resolved = '';
        if (rawName != null && rawName.isNotEmpty) {
          resolved = rawName;
        } else if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',').map((p) => p.trim()).toList();
          resolved = parts.length > 2 ? '${parts[0]}, ${parts[1]}' : displayName;
        }

        if (resolved.isNotEmpty && mounted) {
          setState(() {
            _nameController.text = resolved;
          });
        }
      }
    } catch (_) {
      // Retain fallback coordinates string
    }
  }

  void _shareSelectedPin() {
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
              onPressed: _shareSelectedPin,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Share Pin'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Search Bar for OpenStreetMap live database
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              color: theme.scaffoldBackgroundColor,
              child: TextField(
                key: const Key('osm_search_text_field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (query) => _performSearch(query.trim()),
                decoration: InputDecoration(
                  hintText: 'Search place, cafe, street, landmark (OSM)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          key: const Key('osm_search_clear_button'),
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _searchError = null;
                            });
                          },
                        ),
                      IconButton(
                        key: const Key('osm_search_submit_button'),
                        icon: const Icon(Icons.arrow_forward, size: 20),
                        tooltip: 'Search OSM database',
                        onPressed: () => _performSearch(_searchController.text.trim()),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Safe Presets Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Safe Public Venues:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                              size: 15,
                              color: isSelected ? cs.onPrimary : cs.primary,
                            ),
                            label: Text(preset.name.split(',').first, style: const TextStyle(fontSize: 12)),
                            onSelected: (_) {
                              _selectPreset(preset);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Map Area with Center Pin Overlay & Live Search Results Dropdown
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

                  // Search Results Floating Panel
                  if (_searchResults.isNotEmpty || _searchError != null)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        color: theme.cardColor,
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.travel_explore, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      _searchError != null
                                          ? 'Search Notice'
                                          : 'OpenStreetMap Results (${_searchResults.length})',
                                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _searchResults = [];
                                          _searchError = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (_searchError != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _searchError!,
                                    style: TextStyle(color: cs.error, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: _searchResults.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = _searchResults[index];
                                      return ListTile(
                                        key: Key('osm_search_result_$index'),
                                        dense: true,
                                        leading: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                                        title: Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          item.displayName,
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: const Icon(Icons.north_west, size: 16),
                                        onTap: () => _selectSearchResult(item),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
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
                          key: const Key('osm_zoom_in'),
                          heroTag: 'osm_zoom_in',
                          tooltip: 'Zoom in',
                          onPressed: () {
                            _currentZoom = (_currentZoom + 1).clamp(4.0, 19.0);
                            _mapController.move(_currentCenter, _currentZoom);
                          },
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          key: const Key('osm_zoom_out'),
                          heroTag: 'osm_zoom_out',
                          tooltip: 'Zoom out',
                          onPressed: () {
                            _currentZoom = (_currentZoom - 1).clamp(4.0, 19.0);
                            _mapController.move(_currentCenter, _currentZoom);
                          },
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          key: const Key('osm_recenter'),
                          heroTag: 'osm_recenter',
                          tooltip: 'Relocate to my GPS position',
                          backgroundColor: cs.primaryContainer,
                          onPressed: _isLocating ? null : _relocateToMyPosition,
                          child: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location),
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
                          key: const Key('osm_clear_name_button'),
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
                          key: const Key('osm_preview_gmaps_button'),
                          onPressed: () async {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${_currentCenter.latitude},${_currentCenter.longitude}',
                            );
                            try {
                              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!launched) {
                                await launchUrl(uri, mode: LaunchMode.platformDefault);
                              }
                            } catch (_) {
                              await launchUrl(uri);
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

  void _selectPreset(({double lat, double lng, String name, String tag}) preset) {
    _moveTo(LatLng(preset.lat, preset.lng), preset.name);
  }
}
