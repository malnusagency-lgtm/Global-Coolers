import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class CommunityChallengesScreen extends StatefulWidget {
  const CommunityChallengesScreen({super.key});

  @override
  State<CommunityChallengesScreen> createState() => _CommunityChallengesScreenState();
}

class _CommunityChallengesScreenState extends State<CommunityChallengesScreen> {
  int _selectedTab = 0;
  final SupabaseService _supabaseService = SupabaseService();
  List<String> _joinedIds = [];
  bool _joinedIdsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadJoinedIds();
  }

  Future<void> _loadJoinedIds() async {
    final ids = await _supabaseService.getJoinedChallengeIds();
    if (mounted) setState(() { _joinedIds = ids; _joinedIdsLoaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Location', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Row(
                              children: const [
                                Icon(Icons.location_on, color: AppColors.primary, size: 16),
                                SizedBox(width: 4),
                                Text('Nairobi, Kenya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ),
                          ],
                        ),
                        Consumer<UserProvider>(
                          builder: (context, userProvider, _) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.eco, color: AppColors.primary, size: 18),
                                const SizedBox(width: 4),
                                Text('${userProvider.ecoPoints}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          _buildTab('Active', 0),
                          _buildTab('Upcoming', 1),
                          _buildTab('My\nChallenges', 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              _selectedTab == 2 ? _buildMyChallenges() : _buildAllChallenges(),

              const SizedBox(height: 80),
            ],
          ),
        ),
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

  Widget _buildAllChallenges() {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getChallenges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 100),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Error loading challenges: ${snapshot.error}')),
          );
        }

        final allChallenges = snapshot.data ?? [];
        
        List<dynamic> filtered;
        if (_selectedTab == 0) {
          filtered = allChallenges.where((c) => c['status'] == 'active').toList();
        } else {
          filtered = allChallenges.where((c) => c['status'] == 'upcoming').toList();
        }

        if (filtered.isEmpty) {
          return _buildEmptyState('No challenges found in this category.');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildChallengeCard(filtered[index]),
        );
      },
    );
  }

  Widget _buildMyChallenges() {
    return FutureBuilder<List<dynamic>>(
      future: _supabaseService.getUserChallenges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.only(top: 100), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
        }

        final myChallenges = snapshot.data ?? [];
        if (myChallenges.isEmpty) {
          return _buildEmptyState('You haven\'t joined any challenges yet.\nJoin one from the Active tab!');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: myChallenges.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final cp = myChallenges[index];
            final challenge = cp['challenges'] ?? {};
            final progress = ((cp['progress'] ?? 0) as num).toDouble();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.eco, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(challenge['title'] ?? 'Challenge', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('+${challenge['points_reward'] ?? 50} Pts', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Joined', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${progress.toInt()}% Complete', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : null,
          ),
          child: Center(
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final bool isUpcoming = challenge['status'] == 'upcoming';
    final int points = challenge['points_reward'] ?? 50;
    final String challengeId = challenge['id']?.toString() ?? '';
    final bool isJoined = _joinedIds.contains(challengeId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            color: isUpcoming ? Colors.orange.shade50 : Colors.green.shade50,
            child: Center(
              child: Icon(isUpcoming ? Icons.calendar_today : Icons.eco, size: 40, color: isUpcoming ? Colors.orange : AppColors.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(challenge['title'] ?? 'Challenge', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    Text('+$points Pts', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(challenge['description'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isJoined ? null : () async {
                      try {
                        await _supabaseService.joinChallenge(challengeId);
                        setState(() => _joinedIds.add(challengeId));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Joined ${challenge['title']}! Let\'s go 🚀'), backgroundColor: AppColors.primary),
                          );
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJoined ? Colors.grey.shade200 : (isUpcoming ? const Color(0xFF1A2E1A) : AppColors.primary),
                      foregroundColor: isJoined ? Colors.grey : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isJoined ? '✓ Joined' : (isUpcoming ? 'Join Early' : 'Join Challenge')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
