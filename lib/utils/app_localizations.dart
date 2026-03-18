import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome': 'Welcome back,',
      'impact_title': 'Your Impact',
      'waste_diverted': 'Waste Diverted',
      'eco_points': 'Eco-Points',
      'schedule_pickup': 'Schedule Pickup',
      'live_tracking': 'Live Tracking',
      'redeem_points': 'Redeem Points',
      'community': 'Community',
      'report_issue': 'Report Issue',
      'admin_analytics': 'Admin Analytics',
      'collector_status': 'Collector Status',
      'slogan': 'Clean Neighborhood, Better Life.',
      'taka_taka': 'Waste / Takataka',
      'nyumbani': 'Home',
      'ratiba': 'Schedule',
      'tuzo': 'Rewards',
      'akaunti': 'Profile',
      'edit_profile': 'Edit Profile',
      'my_address': 'My Address',
      'payment_methods': 'Payment Methods',
      'notifications': 'Notifications',
      'help_support': 'Help & Support',
      'privacy_policy': 'Privacy Policy',
      'log_out': 'Log Out',
      'njia': 'Route',
      'historia': 'History',
      'uchambuzi': 'Analytics',
      'ramani': 'Map',
      'mipangilio': 'Settings',
      'pickup_msg': 'Requesting pickup in Nairobi...',
      'success_msg': 'Success! Your waste is being collected.',
    },
    'sw': {
      'welcome': 'Karibu tena,',
      'impact_title': 'Mchango Wako',
      'waste_diverted': 'Takataka Zilizochukuliwa',
      'eco_points': 'Tuzo za Mazingira',
      'schedule_pickup': 'Ratiba ya Kuchukua',
      'live_tracking': 'Kufuatilia Moja kwa Moja',
      'redeem_points': 'Tumia Tuzo',
      'community': 'Jamii',
      'report_issue': 'Ripoti Tatizo',
      'admin_analytics': 'Uchambuzi wa Admin',
      'collector_status': 'Hali ya Mzoaji',
      'slogan': 'Mtaani Safi, Maisha Bora.',
      'taka_taka': 'Takataka / Waste',
      'nyumbani': 'Nyumbani',
      'ratiba': 'Ratiba',
      'tuzo': 'Tuzo',
      'akaunti': 'Wasifu',
      'edit_profile': 'Badili Wasifu',
      'my_address': 'Anuani Yangu',
      'payment_methods': 'Njia za Malipo',
      'notifications': 'Taarifa',
      'help_support': 'Msaada na Mawasiliano',
      'privacy_policy': 'Sera ya Faragha',
      'log_out': 'Ondoka',
      'njia': 'Njia',
      'historia': 'Historia',
      'uchambuzi': 'Uchambuzi',
      'ramani': 'Ramani',
      'mipangilio': 'Mipangilio',
      'pickup_msg': 'Inatafuta mzoaji Nairobi...',
      'success_msg': 'Hongera! Takataka zako zinachukuliwa.',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}
