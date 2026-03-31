import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/supabase_service.dart';

class MyAddressScreen extends StatefulWidget {
  const MyAddressScreen({super.key});

  @override
  State<MyAddressScreen> createState() => _MyAddressScreenState();
}

class _MyAddressScreenState extends State<MyAddressScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final addresses = await _supabaseService.getUserAddresses();
    if (mounted) setState(() { _addresses = addresses; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Addresses'),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _addresses.isEmpty 
            ? _buildEmptyState()
            : _buildAddressList(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Auto-detect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _autoDetectAddress,
                icon: const Icon(Icons.my_location_rounded, color: AppColors.teal, size: 20),
                label: const Text('Auto-Detect Current Location', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: AppColors.teal.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Manual add button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditSheet(context),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: const Text('Add New Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_off_rounded, size: 48, color: AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          const Text('No saved addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add an address manually or auto-detect\nyour current location', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final addr = _addresses[index];
        final isDefault = addr['is_default'] == true;
        final label = addr['label'] ?? 'Address';

        IconData icon = Icons.place_rounded;
        Color iconColor = AppColors.textSecondary;
        if (label == 'Home') { icon = Icons.home_rounded; iconColor = AppColors.primary; }
        else if (label == 'Office') { icon = Icons.work_rounded; iconColor = AppColors.indigo; }
        else if (label == 'School') { icon = Icons.school_rounded; iconColor = AppColors.amber; }
        else { iconColor = AppColors.teal; }

        return Dismissible(
          key: Key(addr['id'] ?? index.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 28),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Delete Address?'),
                content: Text('Remove "$label" from your saved addresses?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            await _supabaseService.deleteUserAddress(addr['id']);
            _loadAddresses();
          },
          child: GestureDetector(
            onTap: () => _showAddressOptions(addr),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isDefault ? Border.all(color: AppColors.primary, width: 2) : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isDefault ? AppColors.primary : iconColor).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: isDefault ? AppColors.primary : iconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          addr['address'] ?? '',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddressOptions(Map<String, dynamic> addr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(addr['label'] ?? 'Address', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOptionTile(Icons.star_rounded, AppColors.amber, 'Set as Default', () {
              Navigator.pop(ctx);
              _supabaseService.setDefaultAddress(addr['id']).then((_) => _loadAddresses());
            }),
            _buildOptionTile(Icons.edit_rounded, AppColors.indigo, 'Edit Address', () {
              Navigator.pop(ctx);
              _showAddEditSheet(context, existingAddress: addr);
            }),
            _buildOptionTile(Icons.delete_rounded, AppColors.error, 'Delete', () async {
              Navigator.pop(ctx);
              await _supabaseService.deleteUserAddress(addr['id']);
              _loadAddresses();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color == AppColors.error ? AppColors.error : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── Auto-detect GPS address ──

  Future<void> _autoDetectAddress() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppColors.teal),
            const SizedBox(width: 20),
            const Expanded(child: Text('Detecting your location...', style: TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );

    try {
      final pos = await _supabaseService.getCurrentPosition();
      if (pos == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not detect location. Please enable GPS.')));
        return;
      }

      final address = await _supabaseService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) Navigator.pop(context);

      if (address != null && mounted) {
        _showAddEditSheet(
          context, 
          prefilledAddress: address,
          prefilledLabel: 'Home',
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not resolve address. Try adding manually.')));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Add / Edit Address Sheet ──

  void _showAddEditSheet(BuildContext context, {
    Map<String, dynamic>? existingAddress, 
    String? prefilledAddress, 
    String? prefilledLabel,
    double? latitude,
    double? longitude,
  }) {
    final isEditing = existingAddress != null;
    final labelController = TextEditingController(text: existingAddress?['label'] ?? prefilledLabel ?? '');
    final addressController = TextEditingController(text: existingAddress?['address'] ?? prefilledAddress ?? '');
    String selectedLabel = existingAddress?['label'] ?? prefilledLabel ?? 'Home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(isEditing ? 'Edit Address' : 'Add New Address', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Label picker
              const Text('Label', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: ['Home', 'Office', 'School', 'Other'].map((label) {
                  final isSelected = selectedLabel == label;
                  IconData ico = Icons.place_rounded;
                  Color col = AppColors.teal;
                  if (label == 'Home') { ico = Icons.home_rounded; col = AppColors.primary; }
                  else if (label == 'Office') { ico = Icons.work_rounded; col = AppColors.indigo; }
                  else if (label == 'School') { ico = Icons.school_rounded; col = AppColors.amber; }

                  return GestureDetector(
                    onTap: () {
                      setSheetState(() => selectedLabel = label);
                      labelController.text = label;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? col.withOpacity(0.12) : Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? col : Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ico, size: 16, color: isSelected ? col : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? col : AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Address field
              const Text('Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter your full address...',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                  suffixIcon: GestureDetector(
                    onTap: () async {
                      final pos = await _supabaseService.getCurrentPosition();
                      if (pos != null) {
                        final addr = await _supabaseService.reverseGeocode(pos.latitude, pos.longitude);
                        if (addr != null) addressController.text = addr;
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.my_location_rounded, color: AppColors.teal, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final addrText = addressController.text.trim();
                    if (addrText.isEmpty) return;

                    final data = {
                      'label': selectedLabel,
                      'address': addrText,
                      'latitude': latitude,
                      'longitude': longitude,
                    };

                    if (isEditing) {
                      await _supabaseService.updateUserAddress(existingAddress['id'], data);
                    } else {
                      await _supabaseService.saveUserAddress(data);
                    }

                    if (mounted) Navigator.pop(ctx);
                    _loadAddresses();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEditing ? 'Address updated!' : 'Address saved!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Save Address', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
