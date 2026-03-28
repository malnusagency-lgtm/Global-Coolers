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
      'landing_title': 'Smart Waste,\nCooler Planet',
      'landing_subtitle': 'Join over 10,000 Kenyans turning waste into wealth.',
      'get_started': 'Get Started',
      'how_it_works': 'How it Works',
      'step1_title': 'Collect',
      'step1_desc': 'Segregate your waste at source.',
      'step2_title': 'Earn',
      'step2_desc': 'Get points for every kg of waste.',
      'step3_title': 'Redeem',
      'step3_desc': 'Use points for Airtime, Electricity & more.',
      'join_cta': 'Join the Safi Mtaani Movement!',
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
      'landing_title': 'Takataka Bora,\nMazingira Safi',
      'landing_subtitle': 'Jiunge na maelfu ya Wakenya wanaogeuza takataka kuwa pesa.',
      'get_started': 'Anza Sasa',
      'how_it_works': 'Jinsi Inavyofanya Kazi',
      'step1_title': 'Kusanya',
      'step1_desc': 'Tenga takataka zako nyumbani.',
      'step2_title': 'Chuma',
      'step2_desc': 'Pata pointi kwa kila kilo ya takataka.',
      'step3_title': 'Tumia',
      'step3_desc': 'Tumia pointi kwa Vocha, Stima na mengine.',
      'join_cta': 'Jiunge na Harakati za Safi Mtaani!',
      'pickup_msg': 'Inatafuta mzoaji Nairobi...',
      'success_msg': 'Hongera! Takataka zako zinachukuliwa.',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}
