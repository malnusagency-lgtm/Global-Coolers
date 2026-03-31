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

class _SchedulePickupScreenState extends State<SchedulePickupScreen> with TickerProviderStateMixin {
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
  List<Map<String, dynamic>> _savedAddresses = [];
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Organic', 'icon': Icons.compost_rounded, 'color': AppColors.organic},
    {'name': 'Plastic', 'icon': Icons.local_drink_rounded, 'color': AppColors.plastic},
    {'name': 'Paper', 'icon': Icons.newspaper_rounded, 'color': AppColors.paper},
    {'name': 'Metal', 'icon': Icons.settings_rounded, 'color': AppColors.metal},
    {'name': 'E-waste', 'icon': Icons.devices_rounded, 'color': AppColors.ewaste},
    {'name': 'Hazardous', 'icon': Icons.warning_amber_rounded, 'color': AppColors.hazardous},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _loadSavedAddresses();
    _fetchLocation();
  }

  Future<void> _loadSavedAddresses() async {
    final addresses = await _supabaseService.getUserAddresses();
    if (mounted) setState(() => _savedAddresses = addresses);
    // Auto-fill default address
    final defaultAddr = await _supabaseService.getDefaultAddress();
    if (defaultAddr != null && _addressController.text.isEmpty && mounted) {
      _addressController.text = defaultAddr['address'] ?? '';
    }
  }

  Future<void> _fetchLocation() async {
    final pos = await _supabaseService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
      if (_addressController.text.isEmpty) {
        // Reverse geocode to get human-readable address
        final address = await _supabaseService.reverseGeocode(pos.latitude, pos.longitude);
        if (address != null && mounted) {
          _addressController.text = address;
        } else if (mounted) {
          _addressController.text = 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}';
        }
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    _pulseController.dispose();
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, size: 48, color: AppColors.amber),
            ),
            const SizedBox(height: 20),
            const Text('Access Restricted', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
        const SizedBox(height: 28),
        const Text('What are we collecting?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _buildCategoryGrid(),
        const SizedBox(height: 28),
        _buildDateTimeSection(context),
        const SizedBox(height: 28),
        _buildPhotoSection(),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pickup Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentPosition != null ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded, 
                      color: _currentPosition != null ? AppColors.primary : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _addressController,
                      focusNode: _addressFocusNode,
                      decoration: const InputDecoration.collapsed(hintText: 'Enter pickup address...'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _addressController.clear();
                      _fetchLocation();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.teal),
                    ),
                  ),
                ],
              ),
              // Saved address chips
              if (_savedAddresses.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedAddresses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final addr = _savedAddresses[index];
                      final isDefault = addr['is_default'] == true;
                      return GestureDetector(
                        onTap: () {
                          _addressController.text = addr['address'] ?? '';
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDefault ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: isDefault ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                addr['label'] == 'Home' ? Icons.home_rounded : addr['label'] == 'Office' ? Icons.work_rounded : Icons.place_rounded,
                                size: 14,
                                color: isDefault ? AppColors.primary : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                addr['label'] ?? 'Address',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDefault ? AppColors.primary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
    final Color catColor = cat['color'];

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? catColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? catColor : Colors.grey.shade200, 
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected ? [BoxShadow(color: catColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: catColor.withOpacity(isSelected ? 0.2 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(cat['icon'], color: catColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              cat['name'], 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? catColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildPickerCard('Date', _selectedDate == null ? 'Pick Date' : '${_selectedDate!.day}/${_selectedDate!.month}', Icons.calendar_today_rounded, AppColors.indigo, () async {
          final picked = await showDatePicker(
            context: context, 
            initialDate: DateTime.now(), 
            firstDate: DateTime.now(), 
            lastDate: DateTime.now().add(const Duration(days: 7))
          );
          if (picked != null) setState(() => _selectedDate = picked);
        })),
        const SizedBox(width: 14),
        Expanded(child: _buildPickerCard('Time', _selectedTime == null ? 'Pick Time' : _selectedTime!.format(context), Icons.access_time_rounded, AppColors.teal, () async {
          final picked = await showTimePicker(
            context: context, 
            initialTime: TimeOfDay.now()
          );
          if (picked != null) setState(() => _selectedTime = picked);
        })),
      ],
    );
  }

  Widget _buildPickerCard(String title, String val, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            ]),
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
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 130, width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200, style: _imageBytes == null ? BorderStyle.solid : BorderStyle.none),
            ),
            child: _imageBytes != null 
              ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 8),
                    const Text('Take a photo of your waste', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isLoading ? null : _handleSchedule,
          child: _isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text('Schedule Collection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
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

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      Navigator.pushNamed(context, '/home');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup requested! Nearby collectors have been notified. 🎉'), backgroundColor: AppColors.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isFindingDriver = false; });
    }
  }

  Widget _buildFindingDriverOverlay() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.15);
        return Container(
          color: Colors.black.withOpacity(0.92),
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: AppColors.accent, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text('Broadcasting request...', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Notifying collectors in your area', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 32),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
