import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class SchedulePickupScreen extends StatefulWidget {
  const SchedulePickupScreen({super.key});

  @override
  State<SchedulePickupScreen> createState() => _SchedulePickupScreenState();
}

class _SchedulePickupScreenState extends State<SchedulePickupScreen> {
  int _selectedCategoryIndex = 0;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _isFindingDriver = false;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  final SupabaseService _supabaseService = SupabaseService();

  Position? _currentPosition;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Organic', 'icon': Icons.compost, 'color': AppColors.organic},
    {'name': 'Plastic', 'icon': Icons.local_drink, 'color': AppColors.plastic},
    {'name': 'Paper', 'icon': Icons.newspaper, 'color': AppColors.paper},
    {'name': 'Metal', 'icon': Icons.build, 'color': AppColors.metal},
    {'name': 'E-waste', 'icon': Icons.phonelink_erase, 'color': AppColors.ewaste},
    {'name': 'Hazardous', 'icon': Icons.warning_amber, 'color': AppColors.hazardous},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final pos = await _supabaseService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentPosition = pos;
        if (_addressController.text.isEmpty) {
          _addressController.text = 'Current Device Location';
        }
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Schedule Pickup'),
      ),
      body: userProvider.role != AppRole.resident 
        ? _buildAccessRestricted() 
        : Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildForm(context),
                    ),
                  ),
                  _buildConfirmButton(context),
                ],
              ),
              if (_isFindingDriver) _buildFindingDriverOverlay(),
            ],
          ),
    );
  }

  Widget _buildAccessRestricted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_rounded, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Access Restricted', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Only household accounts can schedule pickups.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLocationCard(),
        const SizedBox(height: 32),
        const Text('What are we collecting?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildCategoryGrid(),
        const SizedBox(height: 32),
        _buildDateTimeSection(context),
        const SizedBox(height: 32),
        _buildPhotoSection(),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.1))),
      child: Row(
        children: [
          Icon(Icons.location_on, color: _currentPosition != null ? AppColors.primary : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _addressController,
              focusNode: _addressFocusNode,
              decoration: const InputDecoration.collapsed(hintText: 'Enter pickup address or use GPS'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(onPressed: _fetchLocation, icon: const Icon(Icons.my_location, size: 20, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
      itemCount: _categories.length,
      itemBuilder: (context, index) => _buildCategoryItem(index),
    );
  }

  Widget _buildCategoryItem(int index) {
    final cat = _categories[index];
    final isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryIndex = index),
      child: Container(
        decoration: BoxDecoration(color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(cat['icon'], color: isSelected ? AppColors.primary : Colors.grey),
            const SizedBox(height: 8),
            Text(cat['name'], style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildPickerCard('Date', _selectedDate == null ? 'Pick Date' : '${_selectedDate!.day}/${_selectedDate!.month}', Icons.calendar_today, () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
          if (picked != null) setState(() => _selectedDate = picked);
        })),
        const SizedBox(width: 16),
        Expanded(child: _buildPickerCard('Time', _selectedTime == null ? 'Pick Time' : _selectedTime!.format(context), Icons.access_time, () async {
          final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
          if (picked != null) setState(() => _selectedTime = picked);
        })),
      ],
    );
  }

  Widget _buildPickerCard(String title, String val, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 8), Text(val, style: const TextStyle(fontSize: 13))]),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Waste Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 120, width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: _imageBytes != null ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_imageBytes!, fit: BoxFit.cover)) : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: _isLoading ? null : _handleSchedule,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Schedule Collection', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _handleSchedule() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select date and time')));
      return;
    }

    setState(() { _isLoading = true; _isFindingDriver = true; });
    try {
      String? photoUrl;
      if (_imageBytes != null) photoUrl = await _supabaseService.uploadWastePhoto(_imageBytes!, 'jpg');
      
      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day} ${_selectedTime!.format(context)}';
      
      // Use real GPS coordinates if available, otherwise fallback to reasonable default (Nairobi center)
      final lat = _currentPosition?.latitude ?? -1.2921;
      final lng = _currentPosition?.longitude ?? 36.8219;

      await _supabaseService.schedulePickup(
        date: dateStr,
        wasteType: _categories[_selectedCategoryIndex]['name'],
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        photoUrl: photoUrl,
      );

      await Future.delayed(const Duration(seconds: 4)); // UX delay for "Finding Driver"

      if (!mounted) return;
      Navigator.pushNamed(context, '/home');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver assigned! Pickup scheduled successfully. 🎉'), backgroundColor: AppColors.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isFindingDriver = false; });
    }
  }

  Widget _buildFindingDriverOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 4),
          const SizedBox(height: 32),
          const Text('Finding nearest collector...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Wait while Global Coolers optimizes your route', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        ],
      ),
    );
  }
}
