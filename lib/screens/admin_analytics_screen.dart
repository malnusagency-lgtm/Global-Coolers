import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  int _currentNavIndex = 1; // Analytics tab selected by default

  @override
  Widget build(BuildContext context) {
    // Admin dashboard often looks better in dark mode or high contrast
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Admin Analytics', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Row(
              children: [
                Expanded(
                  child: _buildDarkStatCard(
                    'Total Collections',
                    '1,248',
                    '+12%',
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDarkStatCard(
                    'CO2 Reduced',
                    '840 kg',
                    '+5%',
                    AppColors.accent,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Chart Placeholder
            const Text(
              'Waste Collection Trends',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  // Simple bar chart metrics
                  final heights = [0.4, 0.6, 0.5, 0.8, 0.7, 0.9, 0.6];
                  final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: 140 * heights[index],
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.5)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        days[index],
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Heatmap / Regional Data Placeholder
            const Text(
              'Waste Density Heatmap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.map, color: Colors.white24, size: 64),
                  ),
                  Positioned(
                    top: 40,
                    left: 60,
                    child: Icon(Icons.circle, color: Colors.green.withOpacity(0.6), size: 40),
                  ),
                  Positioned(
                    bottom: 50,
                    right: 80,
                    child: Icon(Icons.circle, color: Colors.orange.withOpacity(0.6), size: 60),
                  ),
                  Positioned(
                    top: 80,
                    right: 40,
                    child: Icon(Icons.circle, color: Colors.red.withOpacity(0.6), size: 30),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Recent Alerts
             const Text(
              'System Alerts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAlertItem('High contamination rate in Zone B', '2 mins ago', Colors.redAccent),
            _buildAlertItem('Driver #42 delayed by traffic', '15 mins ago', Colors.orangeAccent),
            _buildAlertItem('New collector registration pending', '1 hr ago', Colors.blueAccent),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        role: UserRole.admin,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
        },
      ),
    );
  }

  Widget _buildDarkStatCard(String title, String value, String change, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Icon(Icons.more_horiz, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.arrow_upward,
                  size: 10,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String message, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
