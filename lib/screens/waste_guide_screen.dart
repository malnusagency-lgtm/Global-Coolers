import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WasteGuideScreen extends StatelessWidget {
  const WasteGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Waste Guide'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search items (e.g., "Bananas", "Batteries")',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Daily Tip Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lightbulb, color: AppColors.info),
                    ),
                    const SizedBox(height: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Tip',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Rinse plastic containers before recycling to prevent contamination.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'Browse by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final categories = [
                    {'name': 'Organic', 'icon': Icons.compost, 'color': AppColors.organic},
                    {'name': 'Plastic', 'icon': Icons.local_drink, 'color': AppColors.plastic},
                    {'name': 'Paper', 'icon': Icons.newspaper, 'color': AppColors.paper},
                    {'name': 'Metal', 'icon': Icons.build, 'color': AppColors.metal},
                    {'name': 'Glass', 'icon': Icons.wine_bar, 'color': AppColors.glass},
                    {'name': 'E-waste', 'icon': Icons.phonelink_erase, 'color': AppColors.ewaste},
                  ];
                  return _buildGuideCard(categories[index]);
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Open camera or scanner
          // Navigator.pushNamed(context, '/scan-waste');
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.center_focus_weak, color: Colors.white),
        label: const Text('Scan to Check', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildGuideCard(Map<String, dynamic> category) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
               color: (category['color'] as Color).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              category['icon'] as IconData,
              color: category['color'] as Color,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            category['name'] as String,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
