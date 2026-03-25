import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/create_account_screen.dart';
import '../screens/home_screen.dart';
import '../screens/schedule_pickup_screen.dart';
import '../screens/live_tracking_screen.dart';
import '../screens/rewards_screen.dart';
import '../screens/report_issue_screen.dart';
import '../screens/waste_guide_screen.dart';
import '../screens/collector_dashboard_screen.dart';
import '../screens/notification_center_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../screens/redeem_points_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/pickup_complete_screen.dart';
import '../screens/support_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/community_challenges_screen.dart';
import '../screens/impact_stats_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const LandingScreen());
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/create-account':
        return MaterialPageRoute(builder: (_) => const CreateAccountScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/schedule-pickup':
        return MaterialPageRoute(builder: (_) => const SchedulePickupScreen());
      case '/live-tracking':
        return MaterialPageRoute(builder: (_) => const LiveTrackingScreen());
      case '/rewards':
        return MaterialPageRoute(builder: (_) => const RewardsScreen());
      case '/report-issue':
        return MaterialPageRoute(builder: (_) => const ReportIssueScreen());
      case '/waste-guide':
        return MaterialPageRoute(builder: (_) => const WasteGuideScreen());
      case '/collector-dashboard':
        return MaterialPageRoute(builder: (_) => const CollectorDashboardScreen());

      case '/notifications':
        return MaterialPageRoute(builder: (_) => const NotificationCenterScreen());
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileSettingsScreen());
      case '/redeem-points':
        return MaterialPageRoute(builder: (_) => const RedeemPointsScreen());
      case '/leaderboard':
        return MaterialPageRoute(builder: (_) => const LeaderboardScreen());
      case '/pickup-complete':
        return MaterialPageRoute(builder: (_) => const PickupCompleteScreen());
      case '/challenges':
        return MaterialPageRoute(builder: (_) => const CommunityChallengesScreen());
      case '/impact-stats':
        return MaterialPageRoute(builder: (_) => const ImpactStatsScreen());
      case '/support':
        return MaterialPageRoute(builder: (_) => const SupportScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
