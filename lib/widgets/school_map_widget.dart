import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/school.dart';
import '../providers/filters_provider.dart';
import '../services/school_service.dart';
import 'tag_chip.dart';

class SchoolMapWidget extends StatefulWidget {
  const SchoolMapWidget({super.key});

  @override
  State<SchoolMapWidget> createState() => _SchoolMapWidgetState();
}

class _SchoolMapWidgetState extends State<SchoolMapWidget> {
  GoogleMapController? _mapController;
  final SchoolService _schoolService = SchoolService();
  List<School> _allSchools = [];
  List<School> _schoolsInRadius = [];
  Position? _userPosition;
  Position? _selectedPosition;
  double _radiusMiles = 10.0;
  double _maxRadiusMiles = 50.0; // Will be calculated based on furthest school
  double? _maxTravelTimeMinutes = 60.0; // Default to 60 minutes when filtering by time
  double _maxTravelTimeAvailable = 120.0; // Will be calculated based on furthest school time
  bool _filterByTime = true; // Default to time-based filtering
  bool _isLoading = true;
  bool _isGeocoding = false;
  bool _isCalculatingDistances = false;
  final TextEditingController _locationController = TextEditingController();
  final Map<String, Marker> _markers = {};
  Circle? _radiusCircle;
  BitmapDescriptor? _grayMarkerIcon; // Cache gray marker
  
  // School type filters (simple on/off, not green/grey/red)
  // Note: 'other' is not selected by default and schools with type 'other' are excluded from map
  final Set<String> _selectedSchoolTypes = {'elementary', 'middle school', 'high school'};
  
  // Saved location preference
  String? _savedLocation;
  bool _useCurrentLocation = true;
  bool _currentLocationButtonVisible = true; // Show button until location is successfully loaded

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
    _createGrayMarker().then((icon) {
      if (mounted) {
        setState(() {
          _grayMarkerIcon = icon;
        });
        _updateMap();
      }
    });
    _initializeMap();
  }
  
  void _excludeOtherSchools() {
    // Ensure 'other' schools are always excluded from filters
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    for (var school in _allSchools) {
      if (school.schoolType == 'other') {
        if (!filtersProvider.excludeLs.contains(school.name)) {
          filtersProvider.excludeLs.add(school.name);
        }
      }
    }
    filtersProvider.saveToFirebase();
  }
  
  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedLocation = prefs.getString('school_map_saved_location');
      _useCurrentLocation = prefs.getBool('school_map_use_current_location') ?? true;
      
      if (_savedLocation != null && _savedLocation != 'current location') {
        _locationController.text = _savedLocation!;
      } else if (_useCurrentLocation) {
        _locationController.text = 'Current Location';
      } else {
        _locationController.text = 'Lehi, Utah';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading saved location: $e');
      }
    }
  }
  
  Future<void> _saveLocation(String location, bool useCurrent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (location == 'Current Location' || location.isEmpty) {
        await prefs.setBool('school_map_use_current_location', true);
        await prefs.remove('school_map_saved_location');
        _useCurrentLocation = true;
        _savedLocation = null;
      } else {
        await prefs.setString('school_map_saved_location', location);
        await prefs.setBool('school_map_use_current_location', false);
        _savedLocation = location;
        _useCurrentLocation = false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving location: $e');
      }
    }
  }

  Future<void> _initializeMap() async {
    // Request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
      }
      return;
    }

    // Determine which location to use based on saved preference
    if (_useCurrentLocation || _savedLocation == null || _savedLocation == 'current location') {
      // Try to get current location
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        // Reverse geocode to get address
        String addressText = 'Current Location';
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final addressParts = <String>[];
            if (place.street != null && place.street!.isNotEmpty) {
              addressParts.add(place.street!);
            }
            if (place.locality != null && place.locality!.isNotEmpty) {
              addressParts.add(place.locality!);
            }
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
              addressParts.add(place.administrativeArea!);
            }
            if (addressParts.isNotEmpty) {
              addressText = addressParts.join(', ');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error reverse geocoding: $e');
          }
        }
        
        setState(() {
          _userPosition = position;
          _selectedPosition = position;
          _locationController.text = addressText;
          _currentLocationButtonVisible = false; // Hide button after successful load
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error getting location: $e');
        }
        // If location not available, default to Lehi, Utah
        await _setDefaultToLehi();
        setState(() {
          _currentLocationButtonVisible = true; // Keep button visible if location failed
        });
      }
    } else if (_savedLocation != null && _savedLocation != 'current location') {
      // Use saved location
      await _searchLocation(_savedLocation!);
      setState(() {
        _currentLocationButtonVisible = true; // Show button if using saved location
      });
    } else {
      // Fallback to Lehi, Utah
      await _setDefaultToLehi();
      setState(() {
        _currentLocationButtonVisible = true; // Show button if using default
      });
    }

    // Load and geocode schools
    await _loadSchools();
  }
  
  Future<void> _setDefaultToLehi() async {
    try {
      final lehiLocations = await locationFromAddress('Lehi, Utah');
      if (lehiLocations.isNotEmpty) {
        final lehiLocation = lehiLocations.first;
        final lehiPosition = Position(
          latitude: lehiLocation.latitude,
          longitude: lehiLocation.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        setState(() {
          _userPosition = lehiPosition;
          _selectedPosition = lehiPosition;
        });
        _locationController.text = 'Lehi, Utah';
        if (kDebugMode) {
          debugPrint('Using default location: Lehi, Utah');
        }
      }
    } catch (e2) {
      if (kDebugMode) {
        debugPrint('Error setting default location to Lehi: $e2');
      }
    }
  }

  Future<void> _loadSchools() async {
    setState(() {
      _isLoading = true;
      _isGeocoding = true;
    });

    try {
      // Load schools from JSON
      await _schoolService.loadSchools();
      _allSchools = _schoolService.schools;

      // Geocode schools
      await _schoolService.geocodeSchools();
      _allSchools = _schoolService.schools;

      setState(() {
        _isGeocoding = false;
        _isCalculatingDistances = true;
      });

      // Ensure we have a position before calculating distances
      if (_selectedPosition == null) {
        // Try to get current location again, or use Lehi, Utah as fallback
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          setState(() {
            _userPosition = position;
            _selectedPosition = position;
          });
        } catch (e) {
          // Default to Lehi, Utah if location still not available
          final lehiLocations = await locationFromAddress('Lehi, Utah');
          if (lehiLocations.isNotEmpty) {
            final lehiLocation = lehiLocations.first;
            final lehiPosition = Position(
              latitude: lehiLocation.latitude,
              longitude: lehiLocation.longitude,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
            setState(() {
              _userPosition = lehiPosition;
              _selectedPosition = lehiPosition;
            });
          }
        }
      }

      // Calculate distances and times
      if (_selectedPosition != null) {
        await _schoolService.calculateDistancesAndTimes(
          _selectedPosition!.latitude,
          _selectedPosition!.longitude,
        );
        _allSchools = _schoolService.schools;
        
        // Calculate max radius and max time based on actual school distances
        double maxDistance = 0.0;
        double maxTime = 0.0;
        for (var school in _allSchools) {
          if (school.schoolType != 'other' && 
              _selectedSchoolTypes.contains(school.schoolType)) {
            if (school.distanceMiles != null && school.distanceMiles! > maxDistance) {
              maxDistance = school.distanceMiles!;
            }
            if (school.travelTime != null) {
              final travelTimeStr = school.travelTime!;
              int? travelMinutes;
              if (travelTimeStr.contains('hrs')) {
                final hours = double.tryParse(travelTimeStr.replaceAll(' hrs', '').trim());
                if (hours != null) {
                  travelMinutes = (hours * 60).round();
                }
              } else if (travelTimeStr.contains('min')) {
                travelMinutes = int.tryParse(travelTimeStr.replaceAll(' min', '').trim());
              }
              if (travelMinutes != null && travelMinutes > maxTime) {
                maxTime = travelMinutes.toDouble();
              }
            }
          }
        }
        // Set max values: furthest school + 1 mile, furthest time + 1 minute (rounded up)
        _maxRadiusMiles = (maxDistance + 1.0).ceilToDouble();
        _maxTravelTimeAvailable = (maxTime + 1.0).ceilToDouble();
        
        // Ensure current radius/time don't exceed max
        if (_radiusMiles > _maxRadiusMiles) {
          _radiusMiles = _maxRadiusMiles;
        }
        if (_maxTravelTimeMinutes != null && _maxTravelTimeMinutes! > _maxTravelTimeAvailable) {
          _maxTravelTimeMinutes = _maxTravelTimeAvailable;
        }
      }

      // Update map
      _updateMap();
      _updateSchoolsInRadius();
      
      // Ensure 'other' schools are excluded from filters
      _excludeOtherSchools();

      setState(() {
        _isLoading = false;
        _isCalculatingDistances = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading schools: $e');
      }
      setState(() {
        _isLoading = false;
        _isGeocoding = false;
        _isCalculatingDistances = false;
      });
    }
  }

  Future<BitmapDescriptor> _createGrayMarker() async {
    // Create a custom gray marker icon using Canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 100.0;
    
    // Draw gray marker shape (teardrop/pin shape similar to default Google marker)
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;
    
    final path = Path();
    // Create teardrop shape
    path.moveTo(size / 2, 0);
    path.arcToPoint(
      Offset(size, size * 0.6),
      radius: Radius.circular(size * 0.3),
      clockwise: false,
    );
    path.lineTo(size * 0.7, size * 0.9);
    path.lineTo(size / 2, size);
    path.lineTo(size * 0.3, size * 0.9);
    path.lineTo(0, size * 0.6);
    path.arcToPoint(
      Offset(size / 2, 0),
      radius: Radius.circular(size * 0.3),
      clockwise: false,
    );
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw border for definition
    final borderPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }
  
  BitmapDescriptor _getMarkerIcon(TagState state) {
    switch (state) {
      case TagState.green:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case TagState.red:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case TagState.gray:
      default:
        // Use custom gray marker if available, otherwise fallback to orange temporarily
        // With area-based selection, schools should be green or red, so gray is rare
        return _grayMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  void _updateMap() {
    if (_mapController == null || _selectedPosition == null) return;

    // Clear existing markers
    _markers.clear();

    // Add user location marker
    _markers['user'] = Marker(
      markerId: const MarkerId('user'),
      position: LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'Your Location'),
    );

    // Add school markers (filtered by selected school types and excluding 'other')
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    for (var school in _allSchools) {
      // Exclude schools with type 'other' from map (they're unconventional programs)
      if (school.schoolType == 'other') {
        continue;
      }
      
      // Only show schools of selected types
      if (!_selectedSchoolTypes.contains(school.schoolType)) {
        continue;
      }
      
      // Filter by travel time if filtering by time
      if (_filterByTime && _maxTravelTimeMinutes != null && school.travelTime != null) {
        final travelTimeStr = school.travelTime!;
        int? travelMinutes;
        if (travelTimeStr.contains('hrs')) {
          final hours = double.tryParse(travelTimeStr.replaceAll(' hrs', '').trim());
          if (hours != null) {
            travelMinutes = (hours * 60).round();
          }
        } else if (travelTimeStr.contains('min')) {
          travelMinutes = int.tryParse(travelTimeStr.replaceAll(' min', '').trim());
        }
        if (travelMinutes != null && travelMinutes > _maxTravelTimeMinutes!) {
          continue;
        }
      }
      
      // Filter by distance if filtering by distance
      if (!_filterByTime) {
        final distanceMeters = Geolocator.distanceBetween(
          _selectedPosition!.latitude,
          _selectedPosition!.longitude,
          school.latitude!,
          school.longitude!,
        );
        final distanceMiles = distanceMeters * 0.000621371;
        if (distanceMiles > _radiusMiles) {
          continue;
        }
      }
      
      if (school.latitude != null && school.longitude != null) {
        // Determine if school is within selected area
        bool isInSelectedArea = false;
        if (_filterByTime && _maxTravelTimeMinutes != null && school.travelTime != null) {
          final travelTimeStr = school.travelTime!;
          int? travelMinutes;
          if (travelTimeStr.contains('hrs')) {
            final hours = double.tryParse(travelTimeStr.replaceAll(' hrs', '').trim());
            if (hours != null) {
              travelMinutes = (hours * 60).round();
            }
          } else if (travelTimeStr.contains('min')) {
            travelMinutes = int.tryParse(travelTimeStr.replaceAll(' min', '').trim());
          }
          isInSelectedArea = travelMinutes != null && travelMinutes <= _maxTravelTimeMinutes!;
        } else if (!_filterByTime) {
          final distanceMeters = Geolocator.distanceBetween(
            _selectedPosition!.latitude,
            _selectedPosition!.longitude,
            school.latitude!,
            school.longitude!,
          );
          final distanceMiles = distanceMeters * 0.000621371;
          isInSelectedArea = distanceMiles <= _radiusMiles;
        }
        
        // Get user's manual override state, or use area-based default
        final manualState = filtersProvider.tagStates[school.name];
        TagState schoolState;
        
        if (manualState != null && manualState != TagState.gray) {
          // User has manually set this school's state (green or red)
          schoolState = manualState;
        } else {
          // Use area-based default: green if in area, red if outside
          schoolState = isInSelectedArea ? TagState.green : TagState.red;
          
          // Update the provider state if not manually set
          if (manualState == null || manualState == TagState.gray) {
            filtersProvider.tagStates[school.name] = schoolState;
            if (schoolState == TagState.green) {
              if (!filtersProvider.includedLs.contains(school.name)) {
                filtersProvider.includedLs.add(school.name);
              }
              filtersProvider.excludeLs.remove(school.name);
            } else {
              if (!filtersProvider.excludeLs.contains(school.name)) {
                filtersProvider.excludeLs.add(school.name);
              }
              filtersProvider.includedLs.remove(school.name);
            }
          }
        }

        _markers[school.name] = Marker(
          markerId: MarkerId(school.name),
          position: LatLng(school.latitude!, school.longitude!),
          icon: _getMarkerIcon(schoolState),
          infoWindow: InfoWindow(
            title: school.name,
            snippet: school.travelTime != null
                ? '${school.distanceMiles?.toStringAsFixed(1)} mi • ${school.travelTime}'
                : school.fullAddress,
          ),
          onTap: () => _showSchoolDetails(school),
        );
      }
    }

    // Update radius circle (only show if filtering by distance)
    if (!_filterByTime) {
      _radiusCircle = Circle(
        circleId: const CircleId('radius'),
        center: LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude),
        radius: _radiusMiles * 1609.34, // Convert miles to meters
        fillColor: Colors.green.withValues(alpha: 0.4), // Increased opacity for visibility
        strokeColor: Colors.green,
        strokeWidth: 3, // Thicker border for visibility
      );
    } else {
      // For time-based filtering, create a polygon/circle based on schools within time limit
      // We'll use a circle that encompasses all schools within the time limit
      // Calculate the max distance for schools within time limit
      double maxDistanceInTime = 0.0;
      if (_maxTravelTimeMinutes != null) {
        for (var school in _allSchools) {
          if (school.schoolType != 'other' && 
              _selectedSchoolTypes.contains(school.schoolType) &&
              school.distanceMiles != null &&
              school.travelTime != null) {
            final travelTimeStr = school.travelTime!;
            int? travelMinutes;
            if (travelTimeStr.contains('hrs')) {
              final hours = double.tryParse(travelTimeStr.replaceAll(' hrs', '').trim());
              if (hours != null) {
                travelMinutes = (hours * 60).round();
              }
            } else if (travelTimeStr.contains('min')) {
              travelMinutes = int.tryParse(travelTimeStr.replaceAll(' min', '').trim());
            }
            if (travelMinutes != null && 
                travelMinutes <= _maxTravelTimeMinutes! &&
                school.distanceMiles! > maxDistanceInTime) {
              maxDistanceInTime = school.distanceMiles!;
            }
          }
        }
      }
      // Add a buffer for smooth edges
      maxDistanceInTime = (maxDistanceInTime * 1.1).ceilToDouble();
      // Create a smooth circle for time-based filtering
      // The circle radius is based on the furthest school within the time limit
      _radiusCircle = Circle(
        circleId: const CircleId('radius'),
        center: LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude),
        radius: maxDistanceInTime * 1609.34, // Convert miles to meters
        fillColor: Colors.green.withValues(alpha: 0.4), // Increased opacity for visibility
        strokeColor: Colors.green,
        strokeWidth: 3, // Thicker border for visibility
      );
    }

    setState(() {});
  }

  void _updateSchoolsInRadius() {
    if (_selectedPosition == null) return;

    List<School> filteredSchools;
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    
    if (_filterByTime) {
      // Filter by time - get all schools and filter by travel time
      filteredSchools = _allSchools
          .where((school) => 
              school.schoolType != 'other' && 
              _selectedSchoolTypes.contains(school.schoolType))
          .where((school) {
            // Filter by travel time
            if (_maxTravelTimeMinutes != null && school.travelTime != null) {
              final travelTimeStr = school.travelTime!;
              int? travelMinutes;
              if (travelTimeStr.contains('hrs')) {
                final hours = double.tryParse(travelTimeStr.replaceAll(' hrs', '').trim());
                if (hours != null) {
                  travelMinutes = (hours * 60).round();
                }
              } else if (travelTimeStr.contains('min')) {
                travelMinutes = int.tryParse(travelTimeStr.replaceAll(' min', '').trim());
              }
              if (travelMinutes != null && travelMinutes > _maxTravelTimeMinutes!) {
                return false;
              }
            }
            return true;
          })
          .toList();
    } else {
      // Filter by distance
      final allSchoolsInRadius = _schoolService.getSchoolsWithinRadius(
        _selectedPosition!.latitude,
        _selectedPosition!.longitude,
        _radiusMiles,
      );
      
      filteredSchools = allSchoolsInRadius
          .where((school) => 
              school.schoolType != 'other' && 
              _selectedSchoolTypes.contains(school.schoolType))
          .toList();
    }
    
    // Update filter states based on area selection
    // Only update schools that haven't been manually overridden
    for (var school in _allSchools) {
      if (school.schoolType == 'other') continue;
      
      bool isInSelectedArea = filteredSchools.contains(school);
      final currentState = filtersProvider.tagStates[school.name];
      
      // Only auto-update if user hasn't manually set the state (or it's gray/unset)
      if (currentState == null || currentState == TagState.gray) {
        if (isInSelectedArea) {
          // School is in selected area - set to green
          filtersProvider.tagStates[school.name] = TagState.green;
          if (!filtersProvider.includedLs.contains(school.name)) {
            filtersProvider.includedLs.add(school.name);
          }
          filtersProvider.excludeLs.remove(school.name);
        } else {
          // School is outside selected area - set to red
          filtersProvider.tagStates[school.name] = TagState.red;
          if (!filtersProvider.excludeLs.contains(school.name)) {
            filtersProvider.excludeLs.add(school.name);
          }
          filtersProvider.includedLs.remove(school.name);
        }
      }
      // If user has manually set green or red, keep that state
    }
    
    filtersProvider.saveToFirebase();
    
    _schoolsInRadius = filteredSchools;
    setState(() {});
  }
  
  void _toggleSchoolType(String schoolType) {
    // Don't allow toggling 'other' - it's always excluded from map
    if (schoolType == 'other') {
      return;
    }
    
    setState(() {
      if (_selectedSchoolTypes.contains(schoolType)) {
        _selectedSchoolTypes.remove(schoolType);
      } else {
        _selectedSchoolTypes.add(schoolType);
      }
    });
    
    // Update excluded words in filters provider
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    
    // Get all schools of unselected types and add them to excluded words
    // Note: 'other' schools are always excluded from map and filters
    final unselectedTypes = {'elementary', 'middle school', 'high school'}
        .difference(_selectedSchoolTypes);
    
    // Remove all school names from excluded first (except 'other' type schools which stay excluded)
    for (var school in _allSchools) {
      if (school.schoolType != 'other') {
        filtersProvider.excludeLs.remove(school.name);
      }
    }
    
    // Add unselected school types' schools to excluded (but not 'other' - they're always excluded)
    for (var school in _allSchools) {
      if (school.schoolType != 'other' && unselectedTypes.contains(school.schoolType)) {
        if (!filtersProvider.excludeLs.contains(school.name)) {
          filtersProvider.excludeLs.add(school.name);
        }
      }
    }
    
    // Always exclude 'other' type schools from filters (they're not on map)
    for (var school in _allSchools) {
      if (school.schoolType == 'other') {
        if (!filtersProvider.excludeLs.contains(school.name)) {
          filtersProvider.excludeLs.add(school.name);
        }
      }
    }
    
    // Save to Firebase
    filtersProvider.saveToFirebase();
    
    // Update map and radius
    _updateMap();
    _updateSchoolsInRadius();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    // Handle "current location" text
    if (query.toLowerCase() == 'current location' || query.toLowerCase() == 'current location') {
      await _returnToCurrentLocation();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _selectedPosition = Position(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });

        // Save the location
        await _saveLocation(query, false);
        
        setState(() {
          _currentLocationButtonVisible = true; // Show button when using searched location
        });

        // Recalculate distances
        await _schoolService.calculateDistancesAndTimes(
          _selectedPosition!.latitude,
          _selectedPosition!.longitude,
        );
        _allSchools = _schoolService.schools;

        // Update map
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_selectedPosition!.latitude, _selectedPosition!.longitude),
          ),
        );
        _updateMap();
        _updateSchoolsInRadius();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding location: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _returnToCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    // Try to get current location
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      // Reverse geocode to get address
      String addressText = 'Current Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressParts = <String>[];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (addressParts.isNotEmpty) {
            addressText = addressParts.join(', ');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error reverse geocoding: $e');
        }
      }
      
      setState(() {
        _userPosition = position;
        _selectedPosition = position;
        _locationController.text = addressText;
        _currentLocationButtonVisible = false; // Hide button after successful load
      });
      await _saveLocation(addressText, true);
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
      await _loadSchools(); // Recalculate distances
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current location: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location. Using default.')),
        );
      }
      // Fallback to saved location or Lehi
      if (_savedLocation != null && _savedLocation != 'current location') {
        await _searchLocation(_savedLocation!);
      } else {
        await _setDefaultToLehi();
        await _loadSchools();
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onRadiusChanged(double value) {
    setState(() {
      _radiusMiles = value;
    });
    _updateMap();
    _updateSchoolsInRadius();
  }

  void _showSchoolDetails(School school) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              school.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(school.fullAddress),
            if (school.distanceMiles != null && school.travelTime != null) ...[
              const SizedBox(height: 8),
              Text(
                '${school.distanceMiles!.toStringAsFixed(1)} miles • ${school.travelTime}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(school.fullAddress)}',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.directions),
              label: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSchoolState(String schoolName) async {
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    // Toggle the school tag state - this will work with the existing filter system
    // This allows manual override of area-based selection
    await filtersProvider.toggleTag('schools-by-city', schoolName);
    setState(() {
      _updateMap();
      _updateSchoolsInRadius(); // Update to reflect manual changes
    });
  }

  // Get schools within the selected area, filtered by school type and sorted alphabetically
  List<School> _getSchoolsWithinArea() {
    final schools = _schoolsInRadius
        .where((school) => 
            school.schoolType != 'other' && 
            _selectedSchoolTypes.contains(school.schoolType))
        .toList();
    schools.sort((a, b) => a.name.compareTo(b.name));
    return schools;
  }

  // Get schools not within the selected area, filtered by school type and sorted alphabetically
  List<School> _getSchoolsNotWithinArea() {
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    final schoolsWithin = _getSchoolsWithinArea();
    final schoolsWithinNames = schoolsWithin.map((s) => s.name).toSet();
    
    final schoolsNotWithin = _allSchools
        .where((school) => 
            school.schoolType != 'other' && 
            _selectedSchoolTypes.contains(school.schoolType) &&
            !schoolsWithinNames.contains(school.name))
        .toList();
    schoolsNotWithin.sort((a, b) => a.name.compareTo(b.name));
    return schoolsNotWithin;
  }

  // Get non-addressed schools (type "other"), sorted alphabetically
  List<School> _getNonAddressedSchools() {
    final schoolsOther = _allSchools
        .where((school) => school.schoolType == 'other')
        .toList();
    schoolsOther.sort((a, b) => a.name.compareTo(b.name));
    return schoolsOther;
  }

  Widget _buildSchoolsWithinDrawer(BuildContext context, FiltersProvider filtersProvider) {
    final schoolsWithin = _getSchoolsWithinArea();
    final title = _filterByTime
        ? 'Schools within ${_maxTravelTimeMinutes?.round() ?? 60} minutes'
        : 'Schools within ${_radiusMiles.toStringAsFixed(1)} miles';

    return ExpansionTile(
      initiallyExpanded: true, // Expanded by default
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      children: [
        if (schoolsWithin.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No schools found within the selected area',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schoolsWithin.map((school) {
                final state = filtersProvider.tagStates[school.name] ?? TagState.gray;
                return MouseRegion(
                  onHover: (_) {
                    // Show tooltip on hover for web
                  },
                  child: GestureDetector(
                    onLongPress: () => _showSchoolDetails(school),
                    child: TagChip(
                      tag: school.name,
                      state: state,
                      isPremium: false,
                      isUnlocked: true,
                      isCustom: false,
                      onTap: () => _toggleSchoolState(school.name),
                      onDelete: null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSchoolsNotWithinDrawer(BuildContext context, FiltersProvider filtersProvider) {
    final schoolsNotWithin = _getSchoolsNotWithinArea();
    final title = _filterByTime
        ? 'Schools not within ${_maxTravelTimeMinutes?.round() ?? 60} minutes'
        : 'Schools not within ${_radiusMiles.toStringAsFixed(1)} miles';

    return ExpansionTile(
      initiallyExpanded: false, // Collapsed by default
      title: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          children: [
            TextSpan(text: 'Schools '),
            TextSpan(
              text: 'not',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            TextSpan(
              text: _filterByTime
                  ? ' within ${_maxTravelTimeMinutes?.round() ?? 60} minutes'
                  : ' within ${_radiusMiles.toStringAsFixed(1)} miles',
            ),
          ],
        ),
      ),
      children: [
        if (schoolsNotWithin.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'All schools are within the selected area',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schoolsNotWithin.map((school) {
                final state = filtersProvider.tagStates[school.name] ?? TagState.gray;
                return MouseRegion(
                  onHover: (_) {
                    // Show tooltip on hover for web
                  },
                  child: GestureDetector(
                    onLongPress: () => _showSchoolDetails(school),
                    child: TagChip(
                      tag: school.name,
                      state: state,
                      isPremium: false,
                      isUnlocked: true,
                      isCustom: false,
                      onTap: () => _toggleSchoolState(school.name),
                      onDelete: null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildNonAddressedSchoolsDrawer(BuildContext context, FiltersProvider filtersProvider) {
    final nonAddressedSchools = _getNonAddressedSchools();
    const tooltipMessage = 'School-types marked as "other" are unconventional types of programs still listed within the school district—such as summer schools or online schools for example, and so they aren\'t included on the map even if they are selected as included (as their listing a physical address could be misleading or confusing).';

    return ExpansionTile(
      initiallyExpanded: false, // Collapsed by default
      title: Row(
        children: [
          Text(
            'Non-addressed Schools',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: tooltipMessage,
            child: Icon(
              Icons.help_outline,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      children: [
        if (nonAddressedSchools.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No non-addressed schools found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tooltip disclaimer text
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tooltipMessage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                // Schools as tags (all gray by default)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: nonAddressedSchools.map((school) {
                    // Non-addressed schools are always gray by default
                    final state = filtersProvider.tagStates[school.name] ?? TagState.gray;
                    return MouseRegion(
                      onHover: (_) {
                        // Show tooltip on hover for web
                      },
                      child: GestureDetector(
                        onLongPress: () => _showSchoolDetails(school),
                        child: TagChip(
                          tag: school.name,
                          state: state,
                          isPremium: false,
                          isUnlocked: true,
                          isCustom: false,
                          onTap: () => _toggleSchoolState(school.name),
                          onDelete: null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtersProvider = Provider.of<FiltersProvider>(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schools By Location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          // Location search field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search location or type "Current Location"',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _locationController.text.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    tooltip: 'Search location (or press Search)',
                                    onPressed: () => _searchLocation(_locationController.text),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _locationController.clear();
                                      _returnToCurrentLocation();
                                    },
                                  ),
                                ],
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {}); // Update to show/hide buttons
                      },
                      onSubmitted: _searchLocation,
                    ),
                  ),
                  // Current location button (only show if not yet loaded)
                  if (_currentLocationButtonVisible)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                          tooltip: 'Use current location',
                          onPressed: _returnToCurrentLocation,
                        ),
                        Text(
                          'Use Current\nLocation',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                ],
              ),
              if (_locationController.text.isNotEmpty && 
                  _locationController.text.toLowerCase() != 'current location' &&
                  _locationController.text.toLowerCase() != 'lehi, utah')
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    'Press Search or tap the search icon to search',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // School type filters
          Row(
            children: [
              Text(
                'School Types:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'School-types marked as "other" are unconventional types of programs still listed within the school district—such as summer schools or online schools for example, and so they aren\'t included on the map even if they are selected as included (as their listing a physical address could be misleading or confusing).',
                child: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['elementary', 'middle school', 'high school', 'other'].map((type) {
              final isSelected = _selectedSchoolTypes.contains(type);
              final isOther = type == 'other';
              return FilterChip(
                label: Text(type),
                selected: isSelected,
                onSelected: isOther ? null : (_) => _toggleSchoolType(type),
                selectedColor: Colors.green.withValues(alpha: 0.3),
                checkmarkColor: Colors.green,
                disabledColor: Colors.grey.withValues(alpha: 0.2),
                tooltip: isOther 
                    ? 'Other schools are excluded from the map (see info icon)'
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Filter by distance or time (toggle)
          Row(
            children: [
              const Text('Filter by: '),
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Distance'),
                      icon: Icon(Icons.straighten),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Time'),
                      icon: Icon(Icons.access_time),
                    ),
                  ],
                  selected: {_filterByTime},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _filterByTime = newSelection.first;
                      if (!_filterByTime) {
                        _maxTravelTimeMinutes = null;
                      } else {
                        _maxTravelTimeMinutes = 60.0; // Default to 60 minutes
                      }
                    });
                    _updateMap();
                    _updateSchoolsInRadius();
                  },
                ),
              ),
              if (_filterByTime)
                Tooltip(
                  message: 'Time estimates are based on current calculations from the user\'s current location if the current location icon was reselected or the user\'s last used location.',
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Distance or Time slider (depending on selection)
          if (!_filterByTime)
            Row(
              children: [
                const Text('Max Distance: '),
                Expanded(
                  child: Slider(
                    value: _radiusMiles,
                    min: 1.0,
                    max: _maxRadiusMiles,
                    divisions: ((_maxRadiusMiles - 1.0) * 10).round(),
                    label: '${_radiusMiles.toStringAsFixed(1)} miles',
                    onChanged: _onRadiusChanged,
                  ),
                ),
                Text('${_radiusMiles.toStringAsFixed(1)} mi'),
              ],
            )
          else
            Row(
              children: [
                const Text('Max Travel Time: '),
                Expanded(
                  child: Slider(
                    value: _maxTravelTimeMinutes ?? 60.0,
                    min: 5.0,
                    max: _maxTravelTimeAvailable,
                    divisions: ((_maxTravelTimeAvailable - 5.0) / 5).round(),
                    label: _maxTravelTimeMinutes != null 
                        ? '${_maxTravelTimeMinutes!.round()} min'
                        : 'No limit',
                    onChanged: (value) {
                      setState(() {
                        _maxTravelTimeMinutes = value;
                      });
                      _updateMap();
                      _updateSchoolsInRadius();
                    },
                  ),
                ),
                Text(_maxTravelTimeMinutes != null 
                    ? '${_maxTravelTimeMinutes!.round()} min'
                    : 'No limit'),
              ],
            ),
          const SizedBox(height: 12),
          // Loading indicator
          if (_isLoading || _isGeocoding || _isCalculatingDistances)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text(
                    _isGeocoding
                        ? 'Geocoding school addresses...'
                        : _isCalculatingDistances
                            ? 'Calculating distances...'
                            : 'Loading...',
                  ),
                ],
              ),
            ),
          // Schools within radius/time as tags in a drawer (show first)
          _buildSchoolsWithinDrawer(context, filtersProvider),
          const SizedBox(height: 8),
          // Schools not within radius/time as tags in a drawer
          _buildSchoolsNotWithinDrawer(context, filtersProvider),
          const SizedBox(height: 8),
          // Non-addressed schools (type "other") in a drawer
          _buildNonAddressedSchoolsDrawer(context, filtersProvider),
          const SizedBox(height: 12),
          // Map (show after drawers)
          if (!_isLoading && _selectedPosition != null)
            SizedBox(
              height: 400,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    _selectedPosition!.latitude,
                    _selectedPosition!.longitude,
                  ),
                  zoom: 11,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _updateMap();
                },
                markers: _markers.values.toSet(),
                circles: _radiusCircle != null ? {_radiusCircle!} : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),
            ),
        ],
      ),
    );
  }
}

