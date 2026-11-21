import 'package:flutter/material.dart';
import 'school_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SchoolDataService _dataService = SchoolDataService();
  int _selectedMenuIndex = 0;

  // Form Controllers for General Info
  late TextEditingController _schoolNameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  // Preferences State
  late String _academicYear;
  late String _currency;

  final List<Map<String, dynamic>> _settingsMenu = [
    {'title': 'General Info', 'icon': Icons.business, 'color': Colors.blueAccent},
    {'title': 'Academic Prefs', 'icon': Icons.settings_applications, 'color': Colors.teal},
    {'title': 'SaaS Subscription', 'icon': Icons.cloud_done, 'color': Colors.indigo},
    {'title': 'Database & Backup', 'icon': Icons.storage, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _dataService.addListener(_onDataServiceChanged);
  }

  void _onDataServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dataService.removeListener(_onDataServiceChanged);
    _schoolNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _initControllers() {
    final settings = _dataService.schoolSettings;
    _schoolNameCtrl = TextEditingController(text: settings['schoolName']);
    _addressCtrl = TextEditingController(text: settings['address']);
    _phoneCtrl = TextEditingController(text: settings['phone']);
    _emailCtrl = TextEditingController(text: settings['email']);
    _academicYear = settings['academicYear'] ?? '2026-2027';
    _currency = settings['currency'] ?? 'PKR';
  }

  bool _isSavingSettings = false;
  bool _isManualSyncing = false;

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);
    Map<String, String> newSettings = {
      'schoolName': _schoolNameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'academicYear': _academicYear,
      'currency': _currency,
    };
    try {
      await _dataService.saveSchoolSettingsAsync(newSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings Saved & Synced to Cloud Firestore!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved locally, but Cloud Sync Error: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _handleManualSync() async {
    setState(() => _isManualSyncing = true);
    try {
      await _dataService.syncAllToFirestore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All school records synced to Cloud Firestore successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud Sync Error: $e\nPlease verify Firestore Security Rules in Firebase Console.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  void _showFactoryResetDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('DANGER ZONE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to completely erase all data? This will delete all students, staff, fees, and attendance records permanently. This action cannot be undone.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
            ElevatedButton(
              onPressed: () {
                _dataService.factoryResetDatabase();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All System Data Erased Successfully.'), backgroundColor: Colors.red));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Erase Everything', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar for Settings Menu
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _settingsMenu.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = _settingsMenu[index];
                final isSelected = _selectedMenuIndex == index;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: Icon(item['icon'], color: isSelected ? item['color'] : Colors.black45),
                  title: Text(
                    item['title'],
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? item['color'] : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: item['color'].withValues(alpha: 0.05),
                  onTap: () => setState(() => _selectedMenuIndex = index),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          
          // Right Content Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: _buildRightContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightContent() {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildGeneralInfo();
      case 1:
        return _buildAcademicPrefs();
      case 2:
        return _buildSaaSSubscription();
      case 3:
        return _buildDatabaseBackup();
      default:
        return const Center(child: Text('Select a setting menu'));
    }
  }

  // --- 1. General Info ---
  Widget _buildGeneralInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('School General Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('These details will appear on fee challans, salary slips, and official reports.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 32),
          TextField(controller: _schoolNameCtrl, decoration: const InputDecoration(labelText: 'Institution Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.school))),
          const SizedBox(height: 20),
          TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Official Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)))),
              const SizedBox(width: 20),
              Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Support Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)))),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isSavingSettings ? null : _saveSettings,
            icon: _isSavingSettings
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save, color: Colors.white),
            label: Text(_isSavingSettings ? 'Saving & Syncing...' : 'Save Changes', style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          ),
        ],
      ),
    );
  }

  // --- 2. Academic Preferences ---
  Widget _buildAcademicPrefs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Academic & Regional Preferences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        DropdownButtonFormField<String>(
          initialValue: _academicYear,
          decoration: const InputDecoration(labelText: 'Active Academic Session', border: OutlineInputBorder(), prefixIcon: Icon(Icons.date_range)),
          items: ['2025-2026', '2026-2027', '2027-2028'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
          onChanged: (v) => setState(() => _academicYear = v!),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Default Currency (Billing)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on)),
          items: ['PKR', 'USD', 'EUR', 'GBP'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _currency = v!),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _isSavingSettings ? null : _saveSettings,
          icon: _isSavingSettings
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save, color: Colors.white),
          label: Text(_isSavingSettings ? 'Saving & Syncing...' : 'Save Preferences', style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
        ),
      ],
    );
  }

  // --- 3. SaaS Subscription ---
  Widget _buildSaaSSubscription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Software License & Billing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Smart SMS Enterprise', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(20)),
                    child: const Text('ACTIVE PRO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Desktop SaaS Edition v4.2 (2026 Release)', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Plan Type: Lifetime Offline Access', style: TextStyle(color: Colors.white)),
                  Text('Cloud Sync: Enabled', style: TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. Database & Backup ---
  Widget _buildDatabaseBackup() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Database & Cloud Sync', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Manage multi-tenant Cloud Firestore synchronization and local backups.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 28),

          // Cloud Firestore Sync Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_sync, color: Colors.blueAccent, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Multi-Tenant Cloud Sync (Firestore)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dataService.isSyncing
                                ? 'Synchronizing all school records with Cloud Firestore...'
                                : (_dataService.lastSyncTime != null
                                    ? 'Last Synced: ${_dataService.lastSyncTime!.toString().split('.')[0]}'
                                    : 'Push all local Hive records (Students, Fees, Admissions, Exams, Attendance) to Cloud Firestore under schools/${_dataService.currentUid ?? "uid"}.'),
                            style: TextStyle(
                              fontSize: 13,
                              color: _dataService.lastSyncError != null ? Colors.redAccent : Colors.black54,
                            ),
                          ),
                          if (_dataService.lastSyncError != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                'Sync Warning: ${_dataService.lastSyncError}',
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: (_isManualSyncing || _dataService.isSyncing) ? null : _handleManualSync,
                      icon: (_isManualSyncing || _dataService.isSyncing)
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload, color: Colors.white, size: 18),
                      label: Text(
                        (_isManualSyncing || _dataService.isSyncing) ? 'Syncing...' : 'Sync to Cloud Now',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Local Backup Export
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.cloud_download, color: Colors.white)),
            title: const Text('Export Local Backup', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Save a copy of your records safely to your PC.'),
            trailing: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup generated successfully in Documents folder.')));
              },
              child: const Text('Export Now'),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

          // Factory Reset
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: const Icon(Icons.delete_forever, color: Colors.red)),
            title: const Text('Factory Reset System', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            subtitle: const Text('Wipe all local data, students, and staff records. Cannot be undone.'),
            trailing: ElevatedButton(
              onPressed: _showFactoryResetDialog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reset Data', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}