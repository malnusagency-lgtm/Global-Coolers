import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class SchedulePickupScreen extends StatefulWidget {
  const SchedulePickupScreen({Key? key}) : super(key: key);

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedDateIndex = 1; 
  int _selectedTimeSlot = 1; 
  bool _isLoading = false;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Organic', 'icon': Icons.compost, 'color': AppColors.organic},
    {'name': 'Plastic', 'icon': Icons.local_drink, 'color': AppColors.plastic},
    {'name': 'Paper', 'icon': Icons.newspaper, 'color': AppColors.paper},
    {'name': 'Metal', 'icon': Icons.build, 'color': AppColors.metal},
    {'name': 'E-waste', 'icon': Icons.phonelink_erase, 'color': AppColors.ewaste},
    {'name': 'Hazardous', 'icon': Icons.warning_amber, 'color': AppColors.hazardous},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Schedule Pickup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
                    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    final currentMonthYear = '${months[now.month - 1]} ${now.year}';
                    
                    return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brief location card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PICKUP LOCATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Plot 45, Kilimani Estate, Nairobi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Waste Category Grid
                    const Text(
                      'What are we collecting?',
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
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        return _buildCategoryItem(index);
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Date Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          currentMonthYear,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final date = now.add(Duration(days: index));
                          final isSelected = _selectedDateIndex == index;
                           
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedDateIndex = index);
                            },
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    weekDays[date.weekday - 1],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Time Slot
                    const Text(
                      'Pickup Time',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTimeSlot('Morning', '8:00 - 11:00 AM', 0)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTimeSlot('Afternoon', '1:00 - 4:00 PM', 1)),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Cost Estimate
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated Cost',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'KES 200',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Image Upload Section
                    const Text(
                      'Waste Photo (Recommended)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: _imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Take a photo of the waste',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
            
            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    
                    try {
                      String? photoUrl;
                      if (_imageBytes != null) {
                        photoUrl = await SupabaseService().uploadWastePhoto(_imageBytes!, 'jpg');
                      }

                      final categoryName = _categories[_selectedCategoryIndex]['name'] as String;
                      final userId = context.read<UserProvider>().userId;
                      
                      // Build a human-readable date from selection
                      final now = DateTime.now();
                      final selectedDate = now.add(Duration(days: _selectedDateIndex));
                      final timeSlotLabel = _selectedTimeSlot == 0 ? '8:00 - 11:00 AM' : '1:00 - 4:00 PM';
                      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} $timeSlotLabel';

                      final pickup = await ApiService.schedulePickup(
                        userId: userId,
                        date: dateStr,
                        wasteType: categoryName, 
                        address: 'Plot 45, Kilimani Estate, Nairobi',
                        photoUrl: photoUrl,
                      );
                      
                      if (!mounted) return;
                      // Fetch the created pickup to get the QR code (Supabase returns it by default or we can let Supabase generate it)
                      // For now, we'll assume the UUID is generated and we can pass a dummy or fetch it
                      Navigator.pushNamed(context, '/pickup-confirmation', arguments: {
                        'qrCode': 'PICKUP_${DateTime.now().millisecondsSinceEpoch}',
                        'wasteType': categoryName,
                      }); 
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to schedule: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Schedule'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(int index) {
    final category = _categories[index];
    final isSelected = _selectedCategoryIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryIndex = index);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: category['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category['icon'],
                color: category['color'],
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String label, String time, int index) {
    final isSelected = _selectedTimeSlot == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTimeSlot = index);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
