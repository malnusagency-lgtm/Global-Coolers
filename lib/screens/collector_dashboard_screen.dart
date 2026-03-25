import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CollectorDashboardScreen> createState() => _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  bool _isOnDuty = true;
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collector Dashboard'),
        automaticallyImplyLeading: false, 
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duty Status Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isOnDuty ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.power_settings_new,
                            color: _isOnDuty ? AppColors.success : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnDuty ? 'You are Online' : 'You are Offline',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _isOnDuty ? 'Ready to receive pickups' : 'Go online to start',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isOnDuty,
                      onChanged: (value) {
                        setState(() => _isOnDuty = value);
                      },
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Todays Pickups', '12', Icons.local_shipping, AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Earned (KES)', '4,500', Icons.account_balance_wallet, AppColors.warning),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'Pickup Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Map Preview (Mock)
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: NetworkImage('https://via.placeholder.com/600x200'), // Or local asset if available
                    fit: BoxFit.cover,
                    opacity: 0.5,
                  ),
                ),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                       Navigator.pushNamed(context, '/route-details');
                    },
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('View Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Queue List
              _buildPickupItem('Plot 45, Kilimani', '2 bags • Organic', '5 mins away', true),
              _buildPickupItem('Sunrise Apts, Westlands', '5 bags • Mixed', '15 mins away', false),
              _buildPickupItem('Java House, Lenana', '10 bags • Commercial', '30 mins away', false),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/qr-scanner');
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scan QR', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        role: UserRole.collector,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 2) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupItem(String location, String details, String time, bool isNext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isNext ? Border.all(color: AppColors.primary, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: isNext ? AppColors.primary : Colors.grey.shade300,
              ),
              Container(
                width: 2,
                height: 30,
                color: Colors.grey.shade200,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isNext ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
