import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/router/routes.dart';
import '../../core/shared-prefrences/shared-prefrences-helper.dart';
import '../../core/supabase/auth-service.dart';
import '../../core/supabase/supabase-config.dart';
import '../../core/supabase/supabase-service.dart';
import '../../main.dart' show appStateInstance;
import '../../theme/app_theme.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late Future<_DoctorProfileData?> _profileFuture;
  final UserService _userService = UserService();
  final FamilyMemberService _familyService = FamilyMemberService();
  final DoctorService _doctorService = DoctorService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final _client = SupabaseConfig.client;

  File? _avatarFile;
  bool _uploadingPhoto = false;
  bool _editing = false;
  bool _saving = false;

  // Current profile data
  _DoctorProfileData? _currentData;

  // Controllers for editing
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _specialtyCtrl;
  final _formKey = GlobalKey<FormState>();

  bool get _isAr =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';

  String tr(String en, String ar) => _isAr ? ar : en;

  @override
  void initState() {
    super.initState();
    final doctorId = SharedPrefsHelper.getString('doctorUid') ??
        SharedPrefsHelper.getString('userId');
    final userId = SharedPrefsHelper.getString('userId');
    debugPrint(
        'Init state - doctorUid: ${SharedPrefsHelper.getString('doctorUid')}, userId: $userId, final doctorId: $doctorId');
    _profileFuture = _loadProfile();
    // Initialize controllers with empty values - they'll be updated when data loads
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _specialtyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  Future<_DoctorProfileData?> _loadProfile() async {
    try {
      final doctorId = SharedPrefsHelper.getString('doctorUid') ??
          SharedPrefsHelper.getString('userId');
      debugPrint('Loading doctor profile for ID: $doctorId');
      if (doctorId == null) {
        debugPrint('Doctor ID is null');
        return null;
      }

      final user = await _doctorService.getDoctorById(doctorId);
      debugPrint('User data: $user');
      final families = await _familyService.getFamiliesByDoctor(doctorId);
      debugPrint('Families data: $families');
      final doctorRow = await _doctorService.getDoctorById(doctorId);
      debugPrint('Doctor row data: $doctorRow');

      // احسب عدد المرضى النشطين بنفس منطق الداشبورد (عدد المرضى الفريدين)
      final Set<String> patientIds = {};
      for (final family in families) {
        final familyId = family['id'] as String?;
        if (familyId == null) continue;
        final relations = await _client
            .from('patient_family_relations')
            .select('patient_id')
            .eq('family_member_id', familyId);
        for (final rel in relations as List) {
          final pid = rel['patient_id'] as String?;
          if (pid != null) patientIds.add(pid);
        }
      }

      debugPrint(
          'Creating DoctorProfileData with: doctorId=$doctorId, user=$user, families=${families.length}, photoUrl=${doctorRow?['photo']}');
      return _DoctorProfileData(
        doctorId: doctorId,
        user: user,
        families: families,
        activePatients: patientIds.length,
        totalCases: patientIds.length,
        photoUrl: doctorRow?['profile_image_url'] as String?,
      );
    } catch (e) {
      debugPrint('Failed to load doctor profile: $e');
      return null;
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleEdit() => setState(() => _editing = !_editing);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final specialty = _specialtyCtrl.text.trim();

      await _doctorService.updateDoctor(_currentData!.doctorId, {
        'name': name,
        'phone': phone.isNotEmpty ? phone : null,
        'email': email.isNotEmpty ? email : null,
        'specialty': specialty.isNotEmpty ? specialty : null,
      });

      setState(() {
        _editing = false;
        _profileFuture = _loadProfile(); // Reload data
      });

      _showSnack(
          tr('Profile updated successfully ', 'تم تحديث الملف الشخصي بنجاح '));
    } catch (e) {
      debugPrint('Doctor profile save error: $e');
      _showSnack(tr('Failed to save changes', 'فشل حفظ التعديلات'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  ImageProvider? _buildAvatarImage(_DoctorProfileData data) {
    if (_avatarFile != null) return FileImage(_avatarFile!);
    final url = data.photoUrl;
    print(url);
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    final file = File(url);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  Future<void> _uploadAvatar(_DoctorProfileData data, File file) async {
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _doctorService.uploadDoctorPhoto(data.doctorId, file);
      await _doctorService.updateDoctorPhoto(data.doctorId, url);
      await SharedPrefsHelper.saveString('doctorPhotoUrl', url);
      if (!mounted) return;
      setState(() {
        _avatarFile = file;
        _profileFuture = _loadProfile();
      });
      _showSnack(tr('Profile photo updated', 'تم تحديث صورة الملف الشخصي'));
    } catch (e) {
      _showSnack('${tr('Failed to upload photo', 'فشل رفع الصورة')}: $e');
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _pickImage(_DoctorProfileData data, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked != null) {
        final file = File(picked.path);
        await _uploadAvatar(data, file);
      }
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      _showSnack('${tr('Image pick error', 'خطأ في اختيار الصورة')}: $e');
    }
  }

  void _openAvatarSheet(_DoctorProfileData data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(tr('Take a photo', 'التقاط صورة')),
              onTap: () => _pickImage(data, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(tr('Choose from gallery', 'اختيار من المعرض')),
              onTap: () => _pickImage(data, ImageSource.gallery),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
    } catch (_) {}
    await SharedPrefsHelper.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building DoctorProfileScreen');
    return SafeArea(
        child: FutureBuilder<_DoctorProfileData?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text(tr('Failed to load profile', 'فشل تحميل الملف الشخصي')),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _profileFuture = _loadProfile();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(tr('Retry', 'إعادة المحاولة')),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        debugPrint(
            'Data loaded successfully: ${data.name}, ${data.email}, ${data.phone}');
        _currentData = data;

        // Update controllers with loaded data
        if (!_editing) {
          _nameCtrl.text = data.name;
          _phoneCtrl.text = data.phone ?? '';
          _emailCtrl.text = data.email ?? '';
          _specialtyCtrl.text = data.specialty ?? '';
          debugPrint(
              'Updated controllers: name=${data.name}, phone=${data.phone}, email=${data.email}, specialty=${data.specialty}');
        }

        final avatarImage = _buildAvatarImage(data);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Language switcher button (top right)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      _isAr ? Icons.language : Icons.translate,
                      color: AppTheme.teal600,
                      size: 28,
                    ),
                        tooltip: _isAr ? 'English' : 'العربية',
                        onPressed: () {
                          if (appStateInstance != null) {
                        final newLocale =
                            _isAr ? const Locale('en') : const Locale('ar');
                        appStateInstance!.changeLanguage(newLocale);
                      }
                    },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Profile Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppTheme.tealGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppTheme.teal500,
                                )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _uploadingPhoto
                                    ? null
                                    : () => _openAvatarSheet(_currentData!),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _uploadingPhoto
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                                AppTheme.teal600),
                                          ),
                                      )
                                          : const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: AppTheme.teal600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            data.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.specialty ?? tr('Doctor', 'طبيب'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFFCFFAFE),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data.experienceLabel,
                              style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions: Edit / Save / Cancel
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _editing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() => _editing = false);
                                    },
                              child: Text(tr('Cancel', 'إلغاء')),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(tr('Save', 'حفظ')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.teal600,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ],
                        )
                      : OutlinedButton.icon(
                          onPressed: _toggleEdit,
                          icon: const Icon(Icons.edit),
                          label: Text(tr('Edit', 'تعديل')),
                        ),
                ),

                const SizedBox(height: 12),

                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                    data.activePatients.toString(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.teal600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr('Active Patients', 'المرضى النشطين'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    data.totalCases.toString(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.cyan600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr('Total Cases', 'إجمالي الحالات'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Contact Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Contact Information', 'بيانات التواصل'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.teal900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_editing) ...[
                          _buildTextField(
                            controller: _nameCtrl,
                            label: tr('Full name', 'الاسم الكامل'),
                            icon: Icons.person,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? tr('Name is required', 'الاسم مطلوب')
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _phoneCtrl,
                            label: tr('Phone', 'الهاتف'),
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _emailCtrl,
                            label: tr('Email', 'البريد الإلكتروني'),
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return tr('Email is required',
                                    'البريد الإلكتروني مطلوب');
                              }
                              if (!v.contains('@')) {
                                return tr('Enter a valid email',
                                    'أدخل بريدًا إلكترونيًا صحيحًا');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _specialtyCtrl,
                            label: tr('Specialty', 'التخصص'),
                            icon: Icons.medical_services,
                          ),
                        ] else ...[
                          _InfoRow(
                              icon: Icons.person,
                              label: tr('Name', 'الاسم'),
                              value: data.name,
                              color: AppTheme.teal500),
                          const SizedBox(height: 10),
                          _InfoRow(
                              icon: Icons.phone,
                              label: tr('Phone', 'الهاتف'),
                              value:
                                  data.phone ?? tr('Not specified', 'غير محدد'),
                              color: AppTheme.teal500),
                          const SizedBox(height: 10),
                          _InfoRow(
                              icon: Icons.email,
                              label: tr('Email', 'البريد الإلكتروني'),
                              value:
                                  data.email ?? tr('Not specified', 'غير محدد'),
                              color: AppTheme.cyan500),
                          const SizedBox(height: 10),
                          _InfoRow(
                              icon: Icons.medical_services,
                              label: tr('Specialty', 'التخصص'),
                              value: data.specialty ??
                                  tr('Not specified', 'غير محدد'),
                              color: AppTheme.teal500),
                        ],
                      ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: Text(
                          tr('Logout', 'تسجيل الخروج'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.teal600),
        filled: true,
        fillColor: AppTheme.teal50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}

class _DoctorProfileData {
  final String doctorId;
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> families;
  final int activePatients;
  final int totalCases;
  final String? photoUrl;

  const _DoctorProfileData({
    required this.doctorId,
    required this.user,
    required this.families,
    required this.activePatients,
    required this.totalCases,
    this.photoUrl,
  });

  String get name => (user?['name'] as String?) ?? 'Doctor';

  String? get email => user?['email'] as String?;

  String? get phone => user?['phone'] as String?;

  String? get specialty => user?['specialty'] as String?;

  String get experienceLabel =>
      'Experience with Alzheimer\'s care'; // TODO: translate if needed
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.gray500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.teal900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
