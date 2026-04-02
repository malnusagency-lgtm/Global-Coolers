import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';

class GlobalNotificationWrapper extends StatefulWidget {
  final Widget child;

  const GlobalNotificationWrapper({super.key, required this.child});

  @override
  State<GlobalNotificationWrapper> createState() => _GlobalNotificationWrapperState();
}

class _GlobalNotificationWrapperState extends State<GlobalNotificationWrapper> {
  StreamSubscription? _subscription;
  final Map<String, String> _knownStatuses = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _subscribeToMyPickups(data.session!.user.id);
      } else {
        _subscription?.cancel();
      }
    });
  }

  void _subscribeToMyPickups(String userId) {
    _subscription?.cancel();
    
    // Listen to changes where this user is either the household OR the collector
    _subscription = Supabase.instance.client
        .from('pickups')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.where((row) => row['user_id'] == userId || row['collector_id'] == userId).toList())
        .listen((pickups) {
      for (var pickup in pickups) {
        final id = pickup['id'].toString();
        final currentStatus = pickup['status'] as String;
        final isResident = pickup['user_id'] == userId;

        // Has status changed?
        if (_knownStatuses.containsKey(id) && _knownStatuses[id] != currentStatus) {
            _dispatchNotification(currentStatus, _knownStatuses[id]!, isResident, pickup);
        }
        
        // Initial setup and tracking
        _knownStatuses[id] = currentStatus;
      }
    });
  }

  void _dispatchNotification(String status, String previousStatus, bool isResident, Map<String, dynamic> pickup) {
    String title = '';
    String message = '';
    IconData icon = Icons.info;
    Color color = AppColors.primary;

    // We only alert the Resident of arrival and transit.
    // The Collector initiated it, they don't need a notification.
    if (isResident) {
      if (status == 'in_transit') {
        title = 'Collector on the way! 🚛';
        message = 'Your collector is heading to your location right now.';
        icon = Icons.local_shipping;
      } else if (status == 'accepted') {
        title = 'Pickup Scheduled 📅';
        message = 'A collector has agreed to pick up your waste at the scheduled time.';
        icon = Icons.calendar_today;
      } else if (status == 'arrived') {
        title = 'Collector Arrived! 📍';
        message = 'The collector is at your location. Please present your QR code.';
        icon = Icons.location_on;
        color = Colors.orange;
      } else if (status == 'completed') {
        title = 'Pickup Complete! 🎉';
        message = 'You just earned ${pickup['points_awarded']} Eco Points!';
        icon = Icons.star;
        color = AppColors.success;
      } else if (status == 'cancelled') {
        title = 'Pickup Cancelled ❌';
        message = 'Your pickup has been successfully cancelled.';
        icon = Icons.cancel;
        color = Colors.red;
      } else if (status == 'scheduled' && (previousStatus == 'accepted' || previousStatus == 'in_transit')) {
        title = 'Collector Cancelled ❌';
        message = 'The collector had to cancel their assignment. We are finding a new collector for you.';
        icon = Icons.person_off_rounded;
        color = Colors.orange;
      }
    } else { // Is Collector
       if (status == 'completed') {
        title = 'Collection Complete! 🎉';
        message = 'Job well done. Waste collected.';
        icon = Icons.verified;
        color = AppColors.success;
      }
    }

    if (title.isNotEmpty) {
      _showOverlayBanner(title, message, icon, color);
    }
  }

  void _showOverlayBanner(String title, String message, IconData icon, Color color) {
    // ScaffoldMessenger is tied to the nearest Scaffold, but using a GlobalKey we can
    // show a floating overlay anywhere in the app without context.
    // For simplicity, we use the root context if possible, but the best way in Flutter
    // without a navigator key is to push an OverlayEntry.
    
    // We will use local Overlay.of(context) inside the Builder of MaterialApp
    // Wait, since this is above MaterialApp, we cannot easily use ScaffoldMessenger.
    // We must pass a GlobalKey<ScaffoldMessengerState> to MaterialApp.
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 8,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                  Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Global key to trigger snackbars anywhere
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
