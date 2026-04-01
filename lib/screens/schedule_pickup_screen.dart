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
  bool _isImmediate = true;

  // ── Weight & Cost ──
  double _selectedWeight = 1.0;
  int _estimatedCost = 0;

  final List<double> _weightOptions = [0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5];

  // Rate per kg for each waste type (KES)
  final List<int> _ratesPerKg = [30, 50, 25, 80, 100, 150];

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
    _updateCost();
  }

  void _updateCost() {
    setState(() {
      _estimatedCost = (_selectedWeight * _ratesPerKg[_selectedCategoryIndex]).round();
    });
  }

  Future<void> _loadSavedAddresses() async {
    final addresses = await _supabaseService.getUserAddresses();
    if (mounted) setState(() => _savedAddresses = addresses);
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Schedule Pickup'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildForm(context),
                ),
              ),
              _buildCostSummary(),
              _buildConfirmButton(context),
            ],
          ),
          if (_isFindingDriver) _buildFindingDriverOverlay(),
        ],
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
        _buildWeightSelector(),
        const SizedBox(height: 28),
        _buildPickupTypeSelector(),
        const SizedBox(height: 28),
        if (!_isImmediate) ...[
          _buildDateTimeSection(context),
          const SizedBox(height: 28),
        ],
        _buildPhotoSection(),
      ],
    );
  }

  // ── Weight Selector ──

  Widget _buildWeightSelector() {
    final Color catColor = _categories[_selectedCategoryIndex]['color'];
    final rate = _ratesPerKg[_selectedCategoryIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estimated Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'KES $rate/kg',
                style: TextStyle(color: catColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _weightOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final w = _weightOptions[index];
              final isSelected = _selectedWeight == w;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedWeight = w);
                  _updateCost();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? catColor : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? catColor : Colors.grey.shade200,
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${w % 1 == 0 ? w.toInt() : w} kg',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Cost Summary Bar ──

  Widget _buildCostSummary() {
    final catColor = _categories[_selectedCategoryIndex]['color'] as Color;
    final residentPoints = (_selectedWeight * 20).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: catColor.withOpacity(0.06),
        border: Border(top: BorderSide(color: catColor.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_categories[_selectedCategoryIndex]['name']} • ${_selectedWeight % 1 == 0 ? _selectedWeight.toInt() : _selectedWeight} kg',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'KES $_estimatedCost',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: catColor),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('+$residentPoints pts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Location Card ──

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
      onTap: () {
        setState(() => _selectedCategoryIndex = index);
        _updateCost();
      },
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

  Widget _buildPickupTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('When should we come?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTypeTab('Pickup Now', Icons.bolt_rounded, _isImmediate, AppColors.amber)),
              Expanded(child: _buildTypeTab('Schedule Later', Icons.calendar_month_rounded, !_isImmediate, AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeTab(String label, IconData icon, bool selected, Color color) {
    return GestureDetector(
      onTap: () => setState(() => _isImmediate = label == 'Pickup Now'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
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
            lastDate: DateTime.now().add(const Duration(days: 7)),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        })),
        const SizedBox(width: 14),
        Expanded(child: _buildPickerCard('Time', _selectedTime == null ? 'Pick Time' : _selectedTime!.format(context), Icons.access_time_rounded, AppColors.teal, () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
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
                  Text(
                    _isImmediate ? 'Request Now • KES $_estimatedCost' : 'Confirm • KES $_estimatedCost',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Future<void> _handleSchedule() async {
    if (!_isImmediate && (_selectedDate == null || _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select date and time')));
      return;
    }

    setState(() { _isLoading = true; _isFindingDriver = true; });
    try {
      String? photoUrl;
      if (_imageBytes != null) photoUrl = await _supabaseService.uploadWastePhoto(_imageBytes!, 'jpg');

      String dateStr;
      if (_isImmediate) {
        final now = DateTime.now();
        dateStr = 'NOW: ${now.year}-${now.month}-${now.day} ${TimeOfDay.now().format(context)}';
      } else {
        dateStr = '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day} ${_selectedTime!.format(context)}';
      }

      final lat = _currentPosition?.latitude ?? -1.2921;
      final lng = _currentPosition?.longitude ?? 36.8219;

      // Schedule and get the pickup data back (includes qr_code_id)
      final pickupData = await _supabaseService.schedulePickup(
        date: dateStr,
        wasteType: _categories[_selectedCategoryIndex]['name'],
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        photoUrl: photoUrl,
        isImmediate: _isImmediate,
        weightKg: _selectedWeight,
        costKes: _estimatedCost,
      );

      final qrCodeId = pickupData['qr_code_id'] ?? 'NO-CODE';
      final pickupId = pickupData['id'].toString();

      if (_isImmediate) {
        // Real-time broadcast: Listen for a driver to accept
        bool collectorFound = false;
        String? collectorId;

        final startTime = DateTime.now();
        await for (final status in _supabaseService.streamPickupStatus(pickupId)) {
          if (status['collector_id'] != null) {
            collectorFound = true;
            collectorId = status['collector_id'].toString();
            break;
          }
          if (DateTime.now().difference(startTime) > const Duration(seconds: 45)) break;
        }

        if (!mounted) return;
        if (collectorFound && collectorId != null) {
          // Navigate to Live Tracking with the collector ID
          Navigator.pushReplacementNamed(
            context,
            '/live-tracking',
            arguments: {
              'collectorId': collectorId,
              'pickupId': pickupId,
              'qrCode': qrCodeId,
              'wasteType': _categories[_selectedCategoryIndex]['name'],
              'weightKg': _selectedWeight,
              'costKes': _estimatedCost,
            },
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collector found! Tracking live. 🚛'), backgroundColor: AppColors.success));
        } else {
          // No immediate collector — navigate to QR confirmation screen
          Navigator.pushReplacementNamed(
            context,
            '/pickup-confirmation',
            arguments: {
              'qrCode': qrCodeId,
              'wasteType': _categories[_selectedCategoryIndex]['name'],
              'weightKg': _selectedWeight,
              'costKes': _estimatedCost,
            },
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent! Show your QR code when the collector arrives.'), backgroundColor: AppColors.primary));
        }
      } else {
        // Scheduled pickup — go to QR confirmation
        Navigator.pushReplacementNamed(
          context,
          '/pickup-confirmation',
          arguments: {
            'qrCode': qrCodeId,
            'wasteType': _categories[_selectedCategoryIndex]['name'],
            'weightKg': _selectedWeight,
            'costKes': _estimatedCost,
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup scheduled! 🎉'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              const SizedBox(height: 8),
              Text(
                '${_categories[_selectedCategoryIndex]['name']} • ${_selectedWeight}kg • KES $_estimatedCost',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, fontWeight: FontWeight.bold),
              ),
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
