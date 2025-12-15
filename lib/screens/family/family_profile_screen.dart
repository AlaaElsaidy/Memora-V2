import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/router/routes.dart';
import '../../config/screen_sizer/size_extension.dart';
import '../../config/shared/widgets/error-dialoge.dart';
import '../../core/models/invitation-model.dart';
import '../../core/shared-prefrences/shared-prefrences-helper.dart';
import '../../core/supabase/auth-service.dart';
import '../../core/supabase/invitation-service.dart';
import '../../core/supabase/patient-family-service.dart';
import '../../core/supabase/supabase-config.dart';
import '../../core/supabase/supabase-service.dart';
import '../../screens/patient/invitations/data/invitation-repo.dart';
import '../../screens/patient/invitations/presentation/cubit/invitation_cubit.dart';
import '../../screens/patient/invitations/presentation/cubit/invitation_state.dart';
import '../../theme/app_theme.dart';
import '../../main.dart' show appStateInstance;

class FamilyProfileScreen extends StatefulWidget {
  const FamilyProfileScreen({super.key});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  String? _currentInvitationCode;
  String? _currentInvitationLink;
  late final InvitationCubit _invitationsCubit;
  List<InvitationModel> _sentInvitations = [];
  bool _isFetchingInvites = false;
  String? _invitesError;
  late Future<_ProfileData?> _profileFuture;
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhoto = false;

  bool get _isAr =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';

  String tr(String en, String ar) => _isAr ? ar : en;

  @override
  void initState() {
    super.initState();
    _invitationsCubit = InvitationCubit(
      InvitationRepo(
        InvitationService(),
        PatientFamilyService(),
        UserService(),
        AuthService(),
        PatientService(),
      ),
    );
    _loadInvitations();
    _profileFuture = _loadProfileData();
  }

  @override
  void dispose() {
    _invitationsCubit.close();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<_ProfileData?> _loadProfileData() async {
    try {
      final userId =
          SharedPrefsHelper.getString("familyUid") ?? SharedPrefsHelper.getString("userId");
      if (userId == null) return null;

      final userService = UserService();
      final familyMemberService = PatientFamilyService();
      final supabase = SupabaseConfig.client;

      final user = await userService.getUser(userId);
      final linkedPatients =
          await familyMemberService.getPatientsByFamily(userId);

      String? doctorName;
      String? doctorPhone;
      String? doctorEmail;
      String? familyImageUrl;

      final familyMember = await supabase
          .from('family_members')
          .select('doctor_id, image_url')
          .eq('id', userId)
          .maybeSingle();
      if (familyMember != null) {
        familyImageUrl = familyMember['image_url'] as String?;
        if (familyMember['doctor_id'] != null) {
          final doctor = await supabase
              .from('users')
              .select('name, phone, email')
              .eq('id', familyMember['doctor_id'])
              .maybeSingle();
          if (doctor != null) {
            doctorName = doctor['name'] as String?;
            doctorPhone = doctor['phone'] as String?;
            doctorEmail = doctor['email'] as String?;
          }
        }
      }

      return _ProfileData(
        userId: userId,
        user: user,
        patients: linkedPatients,
        doctorName: doctorName,
        doctorPhone: doctorPhone,
        doctorEmail: doctorEmail,
        familyImageUrl: familyImageUrl,
      );
    } catch (e) {
      debugPrint('Failed to load profile data: $e');
      return null;
    }
  }

  String _buildInviteMessage(String name) {
    final code = _currentInvitationCode ?? '';
    final deepLink =
        _currentInvitationLink ?? (code.isNotEmpty ? 'alzcare://invite?code=$code' : 'alzcare://invite');

    final friendlyName = name.isEmpty ? '' : '$name, ';

    return tr(
      'Hi ${friendlyName}you have been invited to join as a patient.\n'
          'Invitation code: $code\n'
          'Tap this link after installing the app: $deepLink\n'
          'If the link does not open the app, open AlzCare manually, go to "Accept Invitation", and enter the code above.',
      'مرحباً $friendlyNameتمت دعوتك للانضمام كمريض.\n'
          'رمز الدعوة: $code\n'
          'اضغط على هذا الرابط بعد تثبيت التطبيق: $deepLink\n'
          'إذا لم يفتح الرابط التطبيق، افتح AlzCare يدوياً، اذهب إلى "قبول الدعوة"، وأدخل الرمز أعلاه.',
    );
  }

  Future<void> _loadInvitations() async {
    final familyUid =
        SharedPrefsHelper.getString("familyUid") ?? SharedPrefsHelper.getString("userId");

    if (familyUid == null) {
      setState(() {
        _invitesError = tr("Family member ID not found", "تعذّر العثور على معرف عضو العائلة");
        _isFetchingInvites = false;
      });
      return;
    }

    setState(() {
      _isFetchingInvites = true;
      _invitesError = null;
    });

    await _invitationsCubit.getInvitationsByFamilyMember(familyUid);
  }

  // WhatsApp invite
  Future<void> _sendWhatsApp(String? phone, String message) async {
    if (phone == null || phone.trim().isEmpty) {
      _showSnack(tr('Please provide a phone number', 'يرجى إدخال رقم هاتف'));
      return;
    }
    
    // Extract digits only and ensure +2 prefix
    String phoneNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If phone already has country code (starts with 2), use it, otherwise add +2
    if (!phoneNumber.startsWith('2')) {
      phoneNumber = '2$phoneNumber';
    }
    
    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      _showSnack(tr('Please provide a valid phone number', 'يرجى إدخال رقم هاتف صحيح'));
      return;
    }

    final encoded = Uri.encodeComponent(message);
    final nativeUri = Uri.parse('whatsapp://send?phone=$phoneNumber&text=$encoded');

    if (await canLaunchUrl(nativeUri)) {
      final ok = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      if (!ok) {
        final webUri = Uri.parse('https://wa.me/$phoneNumber?text=$encoded');
        if (!await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
          _showSnack(tr('Could not open WhatsApp', 'تعذّر فتح واتساب'));
        }
      }
    } else {
      final webUri = Uri.parse('https://wa.me/$phoneNumber?text=$encoded');
      if (!await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        _showSnack('Could not open WhatsApp');
      }
    }
  }

  // Send email
  Future<void> _sendEmail(String? email, String subject, String body) async {
    if (email == null || email.trim().isEmpty) {
      _showSnack(tr('Please provide an email address', 'يرجى إدخال عنوان بريد إلكتروني'));
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      _showSnack(tr('Please provide a valid email address', 'يرجى إدخال عنوان بريد إلكتروني صحيح'));
      return;
    }

    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final mailtoUri = Uri.parse('mailto:$email?subject=$encodedSubject&body=$encodedBody');

    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack(tr('Could not open email client', 'تعذّر فتح عميل البريد الإلكتروني'));
    }
  }

  void _openInviteDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider(
        create: (context) => InvitationCubit(
          InvitationRepo(
            InvitationService(),
            PatientFamilyService(),
            UserService(),
            AuthService(),
            PatientService(),
          ),
        ),
        child: BlocListener<InvitationCubit, InvitationState>(
          listener: (context, state) {
            if (state is InvitationFailure) {
              Navigator.pop(ctx);
              showErrorDialog(
                context: context,
                error: state.errorMessage,
                title: "Error",
              );
            } else if (state is InvitationSuccess) {
              _currentInvitationCode = state.invitation.invitationCode;
              _currentInvitationLink =
                  'alzcare://invite?code=${state.invitation.invitationCode}';
              Navigator.pop(ctx);
              _openInviteShareSheet(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
              );
              _loadInvitations();
            }
          },
          child: BlocBuilder<InvitationCubit, InvitationState>(
            builder: (context, state) {
              return AlertDialog(
                title: Text(
                  tr('Invite a Patient', 'دعوة مريض'), style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(18),
                ),),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.teal500.withOpacity(0.1),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.teal500,
                                    width: context.w(2)
                                )
                            ),
                            enabled: true,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.teal500,
                                    width: context.w(2)
                                )
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.teal500,
                                    width: context.w(2)
                                )
                            ),
                            labelStyle: TextStyle(
                                color: AppTheme.teal900,
                                fontSize: context.sp(18),
                                fontWeight: FontWeight.w500
                            ),
                            labelText: tr('Patient Name', 'اسم المريض'),
                            prefixIcon: Icon(
                              Icons.person, color: AppTheme.teal500,
                              size: context.sp(24),),
                          ),
                          validator: (v) =>
                          v == null || v
                              .trim()
                              .isEmpty
                              ? tr('Name is required', 'الاسم مطلوب')
                              : null,
                        ),
                        SizedBox(height: context.h(10)),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.cyan500.withOpacity(0.1),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.cyan500,
                                    width: context.w(2)
                                )
                            ),
                            enabled: true,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.cyan500,
                                    width: context.w(2)
                                )
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.cyan500,
                                    width: context.w(2)
                                )
                            ),
                            labelStyle: TextStyle(
                                color: AppTheme.teal900,
                                fontSize: context.sp(18),
                                fontWeight: FontWeight.w500
                            ),
                            labelText: tr(
                                'Phone (optional)', 'الهاتف (اختياري)'),
                            prefixIcon: Icon(
                              Icons.phone, color: AppTheme.cyan500,
                              size: context.sp(24),),
                          ),
                          keyboardType: TextInputType.phone,
                          onChanged: (value) {
                            // Remove any non-digit characters except what user types
                            final digits = value.replaceAll(
                                RegExp(r'[^0-9]'), '');
                            if (digits.isNotEmpty && value != digits) {
                              phoneCtrl.value = TextEditingValue(
                                text: digits,
                                selection: TextSelection.collapsed(
                                    offset: digits.length),
                              );
                            }
                          },
                        ),
                        SizedBox(height: context.h(10)),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.teal500.withOpacity(0.1),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.teal500,
                                    width: context.w(2)
                                )
                            ),
                            enabled: true,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.teal500,
                                    width: context.w(2)
                                )
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    context.w(15)),
                                borderSide: BorderSide(
                                    color: AppTheme.teal500,
                                    width: context.w(2)
                                )
                            ),
                            labelStyle: TextStyle(
                                color: AppTheme.teal900,
                                fontSize: context.sp(18),
                                fontWeight: FontWeight.w500
                            ),
                            labelText: tr('Email ', 'البريد الإلكتروني '),
                            prefixIcon: Icon(
                              Icons.email, color: AppTheme.teal500,
                              size: context.sp(24),),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return tr('Email is required', 'البريد الإلكتروني مطلوب');
                            }
                            final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegex.hasMatch(v.trim())) {
                              return tr('Invalid email', 'بريد إلكتروني غير صحيح');
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('Cancel', 'إلغاء'), style: TextStyle(
                        color: AppTheme.teal500,
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w600
                    ),),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.teal500,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(context
                                .w(15))
                        )
                    ),
                    onPressed: state is InvitationLoading
                        ? null
                        : () {
                      if (formKey.currentState!.validate()) {
                        final phone = phoneCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final name = nameCtrl.text.trim();

                        if (email.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(tr('Email is required', 'البريد الإلكتروني مطلوب')),
                            ),
                          );
                          return;
                        }

                        final familyUid = SharedPrefsHelper.getString("familyUid") ??
                            SharedPrefsHelper.getString("userId");
                        if (familyUid == null) {
                          Navigator.pop(ctx);
                          showErrorDialog(
                            context: context,
                            error: tr("Family member ID not found", "تعذّر العثور على معرف عضو العائلة"),
                            title: tr("Error", "خطأ"),
                          );
                          return;
                        }

                        // Add +2 prefix to phone number automatically
                        String? finalPhone = phone.isNotEmpty
                            ? (phone.startsWith('+2') ? phone : '+2$phone')
                            : null;

                        context.read<InvitationCubit>().createInvitationFromFamily(
                          familyMemberId: familyUid,
                          patientEmail: email,
                          patientPhone: finalPhone,
                          patientName: name,
                        );
                      }
                    },
                    icon: state is InvitationLoading
                        ? SizedBox(
                      width: context.w(16),
                      height: context.h(16),
                      child: CircularProgressIndicator(strokeWidth: context.w(
                          2), color: AppTheme.cyan500,),
                    )
                        : Icon(Icons.arrow_forward, color: Colors.white,
                      size: context.sp(18),),
                    label: Text(tr('Continue', 'متابعة'), style: TextStyle(
                        color: Colors.white,
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w600
                    ),),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openInviteShareSheet({
    required String name,
    String? phone,
    String? email,
  }) {
    final message = _buildInviteMessage(name);

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
              leading: const Icon(Icons.sms),
              title: Text(tr('Send via SMS', 'إرسال عبر الرسائل النصية')),
              onTap: () {
                Navigator.pop(context);
                _showSnack(tr('SMS feature coming soon', 'ميزة الرسائل النصية قريباً'));
              },
            ),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.green.shade700),
              title: Text(tr('WhatsApp', 'واتساب')),
              onTap: () {
                Navigator.pop(context);
                _sendWhatsApp(phone, message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(tr('Send email', 'إرسال بريد إلكتروني')),
              onTap: () {
                Navigator.pop(context);
                if (email != null && email.isNotEmpty) {
                  _sendEmail(
                    email,
                    tr('Invitation to Join AlzCare', 'دعوة للانضمام إلى AlzCare'),
                    message,
                  );
                } else {
                  _showSnack(tr('Email address is required to send email', 'عنوان البريد الإلكتروني مطلوب لإرسال البريد'));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(tr('Copy link', 'نسخ الرابط')),
              onTap: () {
                Navigator.pop(context);
                final code = _currentInvitationCode;
                final link = _currentInvitationLink;

                if (code == null || code.isEmpty || link == null) {
                  _showSnack(tr('No invitation data available', 'لا توجد بيانات دعوة متاحة'));
                  return;
                }

                Clipboard.setData(
                  ClipboardData(
                    text:
                        tr('Invitation code: $code\nOpen after installing the app: $link', 'رمز الدعوة: $code\nافتح بعد تثبيت التطبيق: $link'),
                  ),
                );
                _showSnack(tr('Invitation info copied', 'تم نسخ معلومات الدعوة'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: Text(tr('Copy code only', 'نسخ الرمز فقط')),
              onTap: () {
                Navigator.pop(context);
                if (_currentInvitationCode == null ||
                    _currentInvitationCode!.isEmpty) {
                  _showSnack(tr('No invitation code available', 'لا يوجد رمز دعوة متاح'));
                  return;
                }
                Clipboard.setData(
                  ClipboardData(text: _currentInvitationCode!),
                );
                _showSnack(tr('Code copied', 'تم نسخ الرمز'));
              },
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: Colors.green.shade700),
              title: Text(tr('Send code via WhatsApp', 'إرسال الرمز عبر واتساب')),
              onTap: () {
                Navigator.pop(context);
                if (_currentInvitationCode == null ||
                    _currentInvitationCode!.isEmpty) {
                  _showSnack(tr('No invitation code available', 'لا يوجد رمز دعوة متاح'));
                  return;
                }
                final codeMessage = tr('Invitation code: ${_currentInvitationCode!}', 'رمز الدعوة: ${_currentInvitationCode!}');
                _sendWhatsApp(phone, codeMessage);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditContactSheet(_ProfileData profile) async {
    final phoneCtrl = TextEditingController(text: profile.userPhone ?? '');
    final emailCtrl = TextEditingController(text: profile.userEmail ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.w(20))),
      ),
      builder: (ctx) =>
          Padding(
            padding: EdgeInsets.only(
              left: context.w(16),
              right: context.w(16),
              bottom: MediaQuery
                  .of(ctx)
                  .viewInsets
                  .bottom + 16,
              top: context.h(24),
            ),
            child: Form(
              key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Edit Contact Info', 'تعديل بيانات التواصل'),
                style: TextStyle(
                  fontSize: context.sp(18),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: context.h(20)),
              TextFormField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.teal500.withOpacity(0.1),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.w(15)),
                      borderSide: BorderSide(
                          color: AppTheme.teal500,
                          width: context.w(2)
                      )
                  ),
                  enabled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.w(15)),
                      borderSide: BorderSide(
                          color: AppTheme.teal500,
                          width: context.w(2)
                      )
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.w(15)),
                      borderSide: BorderSide(
                          color: AppTheme.teal500,
                          width: context.w(2)
                      )
                  ),
                  labelText: tr('Phone number', 'رقم الهاتف'),
                  labelStyle: TextStyle(
                      color: AppTheme.teal900,
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w500
                  ),
                  prefixIcon: Icon(
                    Icons.phone,
                    color: AppTheme.teal500,
                    size: context.sp(24),
                  ),
                ),
              ),
              SizedBox(height: context.h(18)),
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.w(15)),
                      borderSide: BorderSide(
                          color: AppTheme.cyan500,
                          width: context.w(2)
                      )
                  ),
                  enabled: true,
                  labelStyle: TextStyle(
                      color: AppTheme.teal900,
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w500
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.w(15)),
                      borderSide: BorderSide(
                          color: AppTheme.cyan500,
                          width: context.w(2)
                      )
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.w(15)),
                      borderSide: BorderSide(
                          color: AppTheme.cyan500,
                          width: context.w(2)
                      )
                  ),
                  filled: true,
                  fillColor: AppTheme.cyan500.withOpacity(0.1),
                  labelText: tr('Email address', 'البريد الإلكتروني'),
                  prefixIcon: Icon(Icons.email, color: AppTheme.cyan500,
                    size: context.sp(24),),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('Email is required', 'البريد الإلكتروني مطلوب');
                  }
                  final regex =
                  RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                  if (!regex.hasMatch(value.trim())) {
                    return tr(
                        'Enter a valid email', 'أدخل بريدًا إلكترونيًا صحيحًا');
                  }
                  return null;
                },
              ),
              SizedBox(height: context.h(20)),
              SizedBox(
                width: double.infinity,
                height: context.h(45),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal500,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadiusGeometry.circular(
                              context.w(20))
                      )
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final familyMemberService = FamilyMemberService();
                      await familyMemberService.updateFamilyMember(
                          profile.userId, {
                        'phone': phoneCtrl.text
                            .trim()
                            .isEmpty
                            ? null
                            : "+2${phoneCtrl.text.trim()}",
                        'email': emailCtrl.text.trim(),
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        _showSnack(tr(
                            'Contact info updated', 'تم تحديث بيانات التواصل'));
                        setState(() {
                          _profileFuture = _loadProfileData();
                        });
                      }
                    } catch (e) {
                      _showSnack('${tr(
                          'Failed to update', 'فشل التحديث')}: $e');
                    }
                  },
                  child: Text(tr('Save Changes', 'حفظ التغييرات'),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w600
                    ),),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeAvatar(_ProfileData profile) async {
    try {
      final familyId = profile.userId;
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final file = File(picked.path);
      final familyService = FamilyMemberService();
      final url = await familyService.uploadFamilyPhoto(familyId, file);
      await familyService.updateFamily(familyId, {'image_url': url});

      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _profileFuture = _loadProfileData();
      });
      _showSnack(tr('Profile photo updated', 'تم تحديث صورة الملف الشخصي'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      _showSnack('${tr('Failed to update photo', 'فشل تحديث الصورة')}: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService().signOut();
    } catch (_) {}
    await SharedPrefsHelper.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (route) => false,
    );
  }

  Future<void> _callDoctor(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnack(tr('Doctor phone not available', 'رقم هاتف الطبيب غير متاح'));
      return;
    }
    final telUri = Uri.parse('tel:$phone');
    if (!await launchUrl(telUri, mode: LaunchMode.externalApplication)) {
      _showSnack(tr('Could not place call', 'تعذّر إجراء المكالمة'));
    }
  }

  Widget _buildInvitationsCard() {
    Widget content;

    if (_isFetchingInvites) {
      content = Padding(
        padding: EdgeInsets.symmetric(vertical: context.h(24)),
        child: Center(child: CircularProgressIndicator(
          strokeWidth: context.w(2), color: AppTheme.cyan500,)),
      );
    } else if (_invitesError != null) {
      content = Padding(
        padding: EdgeInsets.symmetric(vertical: context.h(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _invitesError!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadInvitations,
              icon: Icon(Icons.refresh, size: context.w(24),),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_sentInvitations.isEmpty) {
      content = Padding(
        padding: EdgeInsets.symmetric(vertical: context.h(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('No invitations sent yet.', 'لم يتم إرسال دعوات بعد.'),
              style: TextStyle(color: AppTheme.gray600,
                  fontSize: context.sp(16),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: context.h(8)),
            OutlinedButton.icon(
              onPressed: _openInviteDialog,
              icon: Icon(Icons.person_add, color: AppTheme.teal500,
                size: context.sp(23),),
              label: Text(tr('Invite a patient', 'دعوة مريض'), style: TextStyle(
                  fontSize: context.sp(15),
                  color: AppTheme.tealDark,
                  fontWeight: FontWeight.w600
              ),),
            ),
          ],
        ),
      );
    } else {
      content = Column(
        children: List.generate(_sentInvitations.length, (index) {
          final invite = _sentInvitations[index];
          final initials = _codeInitials(invite.invitationCode);
          final statusColor = _statusColor(invite.status);

          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.teal50,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.teal600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(invite.patientEmail ?? invite.patientPhone ?? tr('Patient', 'مريض')),
                subtitle: Text(tr('Code: ${invite.invitationCode}', 'الرمز: ${invite.invitationCode}')),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        invite.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invite.createdAt
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.gray500),
                    ),
                  ],
                ),
              ),
              if (index != _sentInvitations.length - 1)
                const Divider(height: 24, thickness: 0.5),
            ],
          );
        }),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(
              tr('Pending Invitations', 'الدعوات المعلقة'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.teal900,
              ),
            ),
            IconButton(
              onPressed: _loadInvitations,
              icon: const Icon(Icons.refresh),
              tooltip: tr('Refresh', 'تحديث'),
            )
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      default:
        return AppTheme.teal600;
    }
  }

  String _codeInitials(String code) {
    if (code.isEmpty) return '--';
    return code.length <= 2 ? code : code.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _invitationsCubit,
      child: BlocListener<InvitationCubit, InvitationState>(
        listener: (context, state) {
          if (state is InvitationsListSuccess) {
            setState(() {
              _sentInvitations = state.invitations;
              _isFetchingInvites = false;
              _invitesError = null;
            });
          } else if (state is InvitationFailure && _isFetchingInvites) {
            setState(() {
              _invitesError = state.errorMessage;
              _isFetchingInvites = false;
            });
          }
        },
        child: SafeArea(
          child: FutureBuilder<_ProfileData?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ProfileErrorView(
                  message: tr('Failed to load profile data', 'فشل تحميل بيانات الملف الشخصي'),
                  onRetry: () {
                    setState(() {
                      _profileFuture = _loadProfileData();
                    });
                  },
                );
              }
              final profile = snapshot.data;
              if (profile == null) {
                return _ProfileErrorView(
                  message: tr('No profile data available', 'لا توجد بيانات ملف شخصي متاحة'),
                  onRetry: () {
                    setState(() {
                      _profileFuture = _loadProfileData();
                    });
                  },
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _profileFuture = _loadProfileData();
                  });
                  await _profileFuture;
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Language switcher button (top right)
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: Icon(
                            _isAr ? Icons.language : Icons.translate,
                            color: AppTheme.teal600,
                            size: context.sp(28),
                          ),
                          tooltip: _isAr ? 'English' : 'العربية',
                          onPressed: () {
                            if (appStateInstance != null) {
                              final newLocale = _isAr ? const Locale('en') : const Locale('ar');
                              appStateInstance!.changeLanguage(newLocale);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ProfileHeader(
                        userName: profile.userName,
                        caregiverRole: profile.user?['role'] ?? tr('Caregiver',
                            'مقدم رعاية'),
                        caringFor: profile.caringForName,
                        avatarUrl: profile.familyImageUrl,
                        uploading: _uploadingPhoto,
                        onAvatarTap: () => _changeAvatar(profile),
                      ),
                      SizedBox(height: context.h(16)),
                      _PatientCard(patients: profile.patients),
                      SizedBox(height: context.h(16)),
                      _ContactInfoCard(
                        phone: profile.userPhone ?? tr('Add phone number',
                            'إضافة رقم هاتف'),
                        email: profile.userEmail ?? tr('Add email',
                            'إضافة بريد إلكتروني'),
                        onEdit: () => _openEditContactSheet(profile),
                      ),
                      SizedBox(height: context.h(16)),
                      _buildInvitationsCard(),
                      SizedBox(height: context.h(16)),
                      _DoctorContactCard(
                        doctorName: profile.doctorName,
                        doctorPhone: profile.doctorPhone,
                        doctorEmail: profile.doctorEmail,
                        onCall: () => _callDoctor(profile.doctorPhone),
                      ),
                      SizedBox(height: context.h(16)),
                      _PrimaryButton(
                        icon: Icons.person_add_alt_1,
                        label: tr('Invite Patient', 'دعوة مريض'),
                        color: AppTheme.teal600,
                        onPressed: _openInviteDialog,
                      ),
                      SizedBox(height: context.h(12)),
                      _PrimaryButton(
                        icon: Icons.logout,
                        label: tr('Logout', 'تسجيل الخروج'),
                        color: Colors.red,
                        onPressed: _handleLogout,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
          width: context.w(40),
          height: context.h(40),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(context.w(10)),
          ),
          child: Icon(
            icon,
            color: color,
            size: context.sp(20),
          ),
        ),
        SizedBox(width: context.w(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: context.sp(14),
                  color: AppTheme.gray500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: context.sp(16),
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

class _ProfileHeader extends StatelessWidget {
  final String userName;
  final String caregiverRole;
  final String? caringFor;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onAvatarTap;

  const _ProfileHeader({
    required this.userName,
    required this.caregiverRole,
    required this.caringFor,
    required this.onAvatarTap,
    this.avatarUrl,
    this.uploading = false,
  });

  bool _isAr(BuildContext context) =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';

  String tr(BuildContext context, String en, String ar) =>
      _isAr(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl!);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(24)),
      decoration: BoxDecoration(
        gradient: AppTheme.tealGradient,
        borderRadius: BorderRadius.circular(context.w(24)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: context.w(58),
                  backgroundColor: Colors.white,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(
                    Icons.person,
                    size: context.sp(48),
                    color: AppTheme.teal500,
                  )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: uploading
                        ? SizedBox(
                      width: context.w(14),
                      height: context.w(14),
                      child: CircularProgressIndicator(
                          strokeWidth: context.w(2)),
                    )
                        : Icon(
                      Icons.photo_camera,
                      size: context.sp(16),
                      color: AppTheme.teal600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.h(2)),
          Text(
            userName,
            style: TextStyle(
              fontSize: context.sp(24),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            caregiverRole,
            style: TextStyle(
              fontSize: context.sp(20),
              color: const Color(0xFFCFFAFE),
            ),
          ),
          if (caringFor != null) ...[
            SizedBox(height: context.h(12)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(16), vertical: context.sp(6)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(context.w(12)),
              ),
              child: Text(
                tr(context, 'Caring for $caringFor', 'رعاية $caringFor'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.sp(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final List<Map<String, dynamic>> patients;

  const _PatientCard({required this.patients});

  bool _isAr(BuildContext context) =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';

  String tr(BuildContext context, String en, String ar) =>
      _isAr(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? firstPatient;
    if (patients.isNotEmpty) {
      firstPatient = patients.first['patients'] as Map<String, dynamic>?;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.w(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'Primary Patient', 'المريض الأساسي'),
              style: TextStyle(
                fontSize: context.sp(18),
                fontWeight: FontWeight.bold,
                color: AppTheme.teal900,
              ),
            ),
            SizedBox(height: context.h(16)),
            if (firstPatient == null)
              Text(
                tr(context,
                    'No patients linked yet. Invite a patient to start tracking.',
                    'لا يوجد مرضى مرتبطين بعد. ادعُ مريضاً لبدء التتبع.'),
                style: const TextStyle(color: AppTheme.gray600),
              )
            else
              Row(
                children: [
                  Container(
                    width: context.w(56),
                    height: context.w(56),
                    decoration: BoxDecoration(
                      color: AppTheme.teal50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppTheme.teal600,
                      size: context.sp(28),
                    ),
                  ),
                  SizedBox(width: context.w(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstPatient['name'] ?? 'Patient',
                          style: TextStyle(
                            fontSize: context.sp(16),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.teal900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  final String phone;
  final String email;
  final VoidCallback onEdit;

  const _ContactInfoCard({
    required this.phone,
    required this.email,
    required this.onEdit,
  });

  bool _isAr(BuildContext context) =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';

  String tr(BuildContext context, String en, String ar) =>
      _isAr(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.w(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'My Contact Information',
                        'بيانات التواصل الخاصة بي'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.teal900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(tr(context, 'Edit', 'تعديل'), style: TextStyle(
                      fontSize: context.sp(18),
                      color: AppTheme.tealDark,
                      fontWeight: FontWeight.w500
                  ),),
                ),
              ],
            ),
            SizedBox(height: context.h(16)),
            _InfoRow(
              icon: Icons.phone,
              label: tr(context, 'Phone', 'الهاتف'),
              value: phone,
              color: AppTheme.teal500,
            ),
            SizedBox(height: context.h(16)),
            _InfoRow(
              icon: Icons.email,
              label: tr(context, 'Email', 'البريد الإلكتروني'),
              value: email,
              color: AppTheme.cyan500,
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorContactCard extends StatelessWidget {
  final String? doctorName;
  final String? doctorPhone;
  final String? doctorEmail;
  final VoidCallback onCall;

  const _DoctorContactCard({
    required this.doctorName,
    required this.doctorPhone,
    required this.doctorEmail,
    required this.onCall,
  });

  bool _isAr(BuildContext context) =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';

  String tr(BuildContext context, String en, String ar) =>
      _isAr(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cyan50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.cyan500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName ?? tr(context, 'No doctor assigned', 'لم يتم تعيين طبيب'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.teal900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctorPhone ?? doctorEmail ?? tr(context, 'Add your doctor to contact them easily.', 'أضف طبيبك للتواصل معه بسهولة.'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.cyan600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: doctorPhone != null ? onCall : null,
              icon: const Icon(Icons.phone, color: AppTheme.cyan600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.gray600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  final String userId;
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> patients;
  final String? doctorName;
  final String? doctorPhone;
  final String? doctorEmail;
  final String? familyImageUrl;

  const _ProfileData({
    required this.userId,
    required this.user,
    required this.patients,
    this.doctorName,
    this.doctorPhone,
    this.doctorEmail,
    this.familyImageUrl,
  });

  String get userName => user?['name'] as String? ?? 'Caregiver';
  String? get userEmail => user?['email'] as String?;
  String? get userPhone => user?['phone'] as String?;

  String? get caringForName {
    if (patients.isEmpty) return null;
    final firstPatient = patients.first['patients'] as Map<String, dynamic>?;
    return firstPatient?['name'] as String?;
  }
}
