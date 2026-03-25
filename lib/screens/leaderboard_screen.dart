import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/supabase_service.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedToggle = 0; 
  int _selectedPeriod = 0; 
  late Future<List<dynamic>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = SupabaseService().getLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nairobi Leaderboard'),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: AppColors.textPrimary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Toggle
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: [
                      _buildToggle('Individuals', 0),
                      _buildToggle('Neighborhoods', 1),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Period Filter
                Row(
                  children: [
                    _buildPeriodChip('This Week', 0),
                    const SizedBox(width: 8),
                    _buildPeriodChip('This Month', 1),
                    const SizedBox(width: 8),
                    _buildPeriodChip('All Time', 2),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          FutureBuilder<List<dynamic>>(
            future: _leaderboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Expanded(child: Center(child: Text('No data found')));
              }

              final users = snapshot.data!;
              final top3 = users.take(3).toList();
              final others = users.skip(3).toList();

              return Expanded(
                child: Column(
                  children: [
                    // Podium
                    SizedBox(
                      height: 250,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // 2nd Place
                              if (top3.length > 1) 
                                _buildPodiumItem(top3[1]['full_name'] ?? 'Alt', '${top3[1]['co2_saved']}kg', 2, 120, Colors.grey.shade200),
                              const SizedBox(width: 8),
                              // 1st Place
                              if (top3.isNotEmpty)
                                _buildPodiumItem(top3[0]['full_name'] ?? 'Winner', '${top3[0]['co2_saved']}kg', 1, 170, AppColors.primary.withOpacity(0.15)),
                              const SizedBox(width: 8),
                              // 3rd Place
                              if (top3.length > 2)
                                _buildPodiumItem(top3[2]['full_name'] ?? 'Alt', '${top3[2]['co2_saved']}kg', 3, 90, Colors.orange.withOpacity(0.15)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Ranked List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: others.length,
                        itemBuilder: (context, index) {
                          final user = others[index];
                          return _buildRankItem(index + 4, user['full_name'] ?? 'Guest', 'Nairobi', '${user['co2_saved']}kg');
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // "You" Sticky Bar
          Consumer<UserProvider>(
            builder: (context, userProvider, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2E1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Text('-', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 16),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.3),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userProvider.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Keep going!', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${userProvider.totalWasteDiverted}kg', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('CO2 Saved', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          if (index == 1) Navigator.pushNamed(context, '/schedule-pickup');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  Widget _buildToggle(String label, int index) {
    final isSelected = _selectedToggle == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedToggle = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)] : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
        ),
        child: Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
      ),
    );
  }

  Widget _buildPodiumItem(String name, String amount, int rank, double height, Color bgColor) {
    final bool isFirst = rank == 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFirst) const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
        if (isFirst) const SizedBox(height: 4),
        Container(
          width: isFirst ? 80 : 60,
          height: isFirst ? 80 : 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isFirst ? AppColors.primary : Colors.grey.shade300, width: isFirst ? 3 : 2),
            color: Colors.grey.shade200,
          ),
          child: Center(child: Icon(Icons.person, size: isFirst ? 40 : 28, color: Colors.grey)),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: rank == 1 ? AppColors.primary : (rank == 2 ? Colors.grey : Colors.orange),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('#$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        Container(
          width: isFirst ? 110 : 90,
          height: height,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isFirst ? 16 : 13)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, color: AppColors.primary, size: 14),
                  const SizedBox(width: 2),
                  Text(amount, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: isFirst ? 14 : 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(int rank, String name, String location, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('CO2 Saved', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
