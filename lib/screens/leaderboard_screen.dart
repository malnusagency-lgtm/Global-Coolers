import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/supabase_service.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedMetric = 0; // 0: CO2 Saved, 1: Eco Points
  bool _isNeighborhood = false;
  late Future<List<dynamic>> _leaderboardFuture;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  void _fetchLeaderboard() {
    setState(() {
      _leaderboardFuture = _supabaseService.getLeaderboard(
        sortBy: _selectedMetric == 0 ? 'co2_saved' : 'eco_points',
        isNeighborhood: _isNeighborhood,
      );
    });
  }

  String _formatMetric(dynamic value) {
    final double metricVal = (value ?? 0.0) is int 
        ? (value as int).toDouble() 
        : (value as double? ?? 0.0);
    
    if (_selectedMetric == 0) {
      return '${metricVal.toStringAsFixed(1)}kg';
    } else {
      return '${metricVal.toInt()} pts';
    }
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
        title: const Text('Top Recyclers', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.share, color: AppColors.textPrimary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                // Scope Toggle (Global / Neighborhood)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () { if (_isNeighborhood) { _isNeighborhood = false; _fetchLeaderboard(); } },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isNeighborhood ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.public, size: 16, color: !_isNeighborhood ? AppColors.primary : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Global', style: TextStyle(fontWeight: !_isNeighborhood ? FontWeight.bold : FontWeight.normal, color: !_isNeighborhood ? AppColors.primary : AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () { if (!_isNeighborhood) { _isNeighborhood = true; _fetchLeaderboard(); } },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isNeighborhood ? AppColors.teal.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_rounded, size: 16, color: _isNeighborhood ? AppColors.teal : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Neighborhood', style: TextStyle(fontWeight: _isNeighborhood ? FontWeight.bold : FontWeight.normal, color: _isNeighborhood ? AppColors.teal : AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Metric Toggle
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: [
                      _buildToggle('CO2 Saved', 0),
                      _buildToggle('Eco Points', 1),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          FutureBuilder<List<dynamic>>(
            future: _leaderboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Expanded(child: Center(child: Text('No rank data found. Be the first!')));
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
                                _buildPodiumItem(top3[1]['full_name'] ?? 'Guest', _formatMetric(_selectedMetric == 0 ? top3[1]['co2_saved'] : top3[1]['eco_points']), 2, 120, Colors.grey.shade200),
                              const SizedBox(width: 8),
                              // 1st Place
                              if (top3.isNotEmpty)
                                _buildPodiumItem(top3[0]['full_name'] ?? 'Champion', _formatMetric(_selectedMetric == 0 ? top3[0]['co2_saved'] : top3[0]['eco_points']), 1, 170, AppColors.primary.withOpacity(0.15)),
                              const SizedBox(width: 8),
                              // 3rd Place
                              if (top3.length > 2)
                                _buildPodiumItem(top3[2]['full_name'] ?? 'Guest', _formatMetric(_selectedMetric == 0 ? top3[2]['co2_saved'] : top3[2]['eco_points']), 3, 90, Colors.orange.withOpacity(0.15)),
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
                          final amountStr = _formatMetric(_selectedMetric == 0 ? user['co2_saved'] : user['eco_points']);
                          return _buildRankItem(index + 4, user['full_name'] ?? 'Anonymous', amountStr);
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
            builder: (context, userProvider, _) {
              final valStr = _selectedMetric == 0 
                  ? '${userProvider.totalWasteDiverted}kg'
                  : '${userProvider.ecoPoints} pts';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2E1A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Text('★', style: TextStyle(color: AppColors.accent, fontSize: 18)),
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
                        const Text('Your Current Ranking', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(valStr, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(_selectedMetric == 0 ? 'CO2 Saved' : 'Total Points', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              );
            },
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
    final isSelected = _selectedMetric == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedMetric != index) {
            _selectedMetric = index;
            _fetchLeaderboard();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
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
          width: isFirst ? 70 : 56,
          height: isFirst ? 70 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isFirst ? AppColors.primary : Colors.grey.shade300, width: isFirst ? 3 : 2),
            color: Colors.white,
          ),
          child: Center(child: Icon(Icons.person, size: isFirst ? 32 : 24, color: Colors.grey)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: rank == 1 ? AppColors.primary : (rank == 2 ? Colors.grey.shade700 : Colors.orange.shade700),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('#$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        Container(
          width: isFirst ? 110 : 90,
          height: height,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.split(' ').first, 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isFirst ? 15 : 13),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_selectedMetric == 0 ? Icons.eco : Icons.star, color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(amount, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: isFirst ? 13 : 11)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(int rank, String name, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textSecondary)),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_selectedMetric == 0 ? 'Saved' : 'Earned', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
