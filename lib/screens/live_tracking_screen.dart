import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  LatLng _collectorLocation = const LatLng(-1.2960, 36.8150);
  final LatLng _userLocation = const LatLng(-1.2921, 36.8219);
  StreamSubscription? _locationSubscription;
  final SupabaseService _supabaseService = SupabaseService();
  String _eta = '12 mins';

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    // In a real app, we'd pass the collectorId to track. 
    // Here we'll listen for any collector updates or a specific demo ID.
    _locationSubscription = _supabaseService.streamLocation('DEMO_COLLECTOR_ID').listen((data) {
      if (data.isNotEmpty) {
        final profile = data.first;
        if (profile['latitude'] != null && profile['longitude'] != null) {
          setState(() {
            _collectorLocation = LatLng(profile['latitude'], profile['longitude']);
            // Simple ETA calculation mockup
            _eta = '8 mins'; 
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.globalcoolers.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation,
                    width: 50,
                    height: 50,
                    child: _buildMapMarker(Icons.home, AppColors.primary),
                  ),
                  Marker(
                    point: _collectorLocation,
                    width: 50,
                    height: 50,
                    child: _buildMapMarker(Icons.local_shipping, AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Arriving in', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(_eta, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('On route', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const CircleAvatar(radius: 24, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('John Kamau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                            Text('4.8 ★ • KBZ 123A', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      _buildActionButton(Icons.phone, AppColors.success),
                      const SizedBox(width: 12),
                      _buildActionButton(Icons.message, AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), onPressed: () {}),
    );
  }

  Widget _buildMapMarker(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
