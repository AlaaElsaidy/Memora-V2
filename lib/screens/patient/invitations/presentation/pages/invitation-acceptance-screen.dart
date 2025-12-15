import 'package:alzcare/config/router/routes.dart';
import 'package:alzcare/config/screen_sizer/size_extension.dart';
import 'package:alzcare/config/shared/widgets/error-dialoge.dart';
import 'package:alzcare/config/shared/widgets/loading.dart';
import 'package:alzcare/config/shared/widgets/custom-button.dart';
import 'package:alzcare/core/models/invitation-model.dart';
import 'package:alzcare/core/shared-prefrences/shared-prefrences-helper.dart';
import 'package:alzcare/core/supabase/auth-service.dart';
import 'package:alzcare/core/supabase/invitation-service.dart';
import 'package:alzcare/core/supabase/patient-family-service.dart';
import 'package:alzcare/core/supabase/supabase-service.dart';
import 'package:alzcare/screens/patient/invitations/data/invitation-repo.dart';
import 'package:alzcare/screens/patient/invitations/presentation/cubit/invitation_cubit.dart';
import 'package:alzcare/screens/patient/invitations/presentation/cubit/invitation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:alzcare/config/utilis/app_colors.dart';
import 'package:alzcare/config/shared/widgets/decore-circle.dart';
import 'package:alzcare/config/shared/widgets/custom-text-form.dart';
import 'package:alzcare/config/shared/widgets/field-wrapper.dart';

class InvitationAcceptanceScreen extends StatefulWidget {
  final String? invitationCode;

  const InvitationAcceptanceScreen({
    super.key,
    this.invitationCode,
  });

  @override
  State<InvitationAcceptanceScreen> createState() => _InvitationAcceptanceScreenState();
}

class _InvitationAcceptanceScreenState extends State<InvitationAcceptanceScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFallbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  InvitationModel? _invitationDetails;
  String? _patientUid;
  bool _isCreatingAccount = false;
  bool _isFetchingInvite = false;
  late final InvitationCubit _invitationCubit;

  bool get _isAr =>
      (Localizations
          .maybeLocaleOf(context)
          ?.languageCode ?? 'en') == 'ar';

  String tr(String en, String ar) => _isAr ? ar : en;

  @override
  void initState() {
    super.initState();
    _invitationCubit = InvitationCubit(
      InvitationRepo(
        InvitationService(),
        PatientFamilyService(),
        UserService(),
        AuthService(),
        PatientService(),
      ),
    );
    if (widget.invitationCode != null) {
      _codeController.text = widget.invitationCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchInvitation(widget.invitationCode!);
      });
    }
    _patientUid = SharedPrefsHelper.getString("patientUid");
  }

  @override
  void dispose() {
    _invitationCubit.close();
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFallbackController.dispose();
    super.dispose();
  }

  void _fetchInvitation(String code) {
    setState(() {
      _isFetchingInvite = true;
    });
    _invitationCubit.getInvitationByCode(code);
  }

  Future<void> _createPatientAccount() async {
    final invitation = _invitationDetails;
    if (invitation == null) {
      showErrorDialog(
        context: context,
        error: "Please fetch the invitation details first.",
        title: "Missing Invitation",
      );
      return;
    }

    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final email = invitation.patientEmail ?? _emailFallbackController.text.trim();

    if (name.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      showErrorDialog(
        context: context,
        error: "Name and password are required.",
        title: "Incomplete Form",
      );
      return;
    }

    if (password != confirmPassword) {
      showErrorDialog(
        context: context,
        error: "Passwords do not match.",
        title: "Password Error",
      );
      return;
    }

    if (email.isEmpty) {
      showErrorDialog(
        context: context,
        error: "This invitation does not include an email. Please enter one.",
        title: "Email Required",
      );
      return;
    }

    setState(() => _isCreatingAccount = true);
    final authService = AuthService();
    final patientService = PatientService();

    try {
      final response = await authService.signUp(
        email: email,
        password: password,
        name: name,
        role: 'patient',
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Unable to create account. Please try again.");
      }

      await SharedPrefsHelper.saveString("patientUid", user.id);
      await SharedPrefsHelper.saveString("userId", user.id);

      await patientService.addPatient(
        patientId: user.id,
        age: 0,
        name: name,
        gender: 'Male',
      );

      setState(() {
        _patientUid = user.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! You can now accept the invitation.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      showErrorDialog(
        context: context,
        error: e.toString(),
        title: "Account Creation Failed",
      );
    } finally {
      setState(() => _isCreatingAccount = false);
    }
  }

  Future<void> _handleAcceptInvitation() async {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeController.text.trim().toUpperCase();
    final patientUid = _patientUid;

    if (patientUid == null) {
      showErrorDialog(
        context: context,
        error:
            "No patient account detected. Please create your account from this invitation before accepting.",
        title: "Account Required",
      );
      return;
    }

    await _invitationCubit.acceptInvitation(
          invitationCode: code,
          patientId: patientUid,
        );
  }

  Future<void> _handleRejectInvitation() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      showErrorDialog(
        context: context,
        error: "Please enter invitation code",
        title: "Error",
      );
      return;
    }
    await _invitationCubit.rejectInvitation(code);
  }

  Widget _buildInvitationDetails() {
    final invitation = _invitationDetails;
    if (invitation == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: context.h(20)),
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: AppColors.borderColor.withOpacity(.3),
        ),
        borderRadius: BorderRadius.circular(context.w(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Invitation Details', 'تفاصيل الدعوة'),
            style: TextStyle(
              fontSize: context.sp(16),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0E3E3B),
            ),
          ),
          SizedBox(height: context.h(12)),
          _DetailRow(label: tr('Status', 'الحالة'), value: invitation.status),
          _DetailRow(
            label: tr('Family Member ID', 'معرف عضو العائلة'),
            value: invitation.familyMemberId ?? tr('Not provided', 'غير محدد'),
          ),
          _DetailRow(
            label: tr('Email', 'البريد الإلكتروني'),
            value: invitation.patientEmail ??
                (_patientUid != null ? tr(
                    'Linked to your account', 'مرتبط بحسابك') : tr(
                    'Not provided', 'غير محدد')),
          ),
          _DetailRow(
            label: tr('Phone', 'الهاتف'),
            value: invitation.patientPhone ?? tr('Not provided', 'غير محدد'),
          ),
          SizedBox(height: context.h(12)),
          Row(
            children: [
              Icon(
                invitation.isExpired ? Icons.warning : Icons.pending,
                color: invitation.isExpired ? Colors.red : Colors.orange,
                size: 18,
              ),
              SizedBox(width: context.w(8)),
              Expanded(
                child: Text(
                  invitation.isExpired
                      ? tr(
                      'This invitation has expired. Ask your family member to send a new one.',
                      'انتهت صلاحية هذه الدعوة. اطلب من عضو العائلة إرسال دعوة جديدة.')
                      : tr('This invitation expires on ${invitation.expiresAt
                      .toLocal()
                      .toString()
                      .split(" ")
                      .first}.',
                      'تنتهي صلاحية هذه الدعوة في ${invitation.expiresAt
                          .toLocal()
                          .toString()
                          .split(" ")
                          .first}.'),
                  style: TextStyle(
                    color: invitation.isExpired ? Colors.red : Colors
                        .orange[700],
                    fontSize: context.sp(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCreationForm() {
    if (_patientUid != null) return const SizedBox.shrink();
    if (_invitationDetails == null) {
      return Padding(
        padding: EdgeInsets.only(top: context.h(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Need an account?', 'تحتاج حساب؟'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: context.sp(14),
                color: const Color(0xFF0E3E3B),
              ),
            ),
            SizedBox(height: context.h(8)),
            Text(
              tr('Fetch invitation details first to start account creation.',
                  'اجلب تفاصيل الدعوة أولاً لبدء إنشاء الحساب.'),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: context.sp(12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: context.h(24)),
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: AppColors.borderColor.withOpacity(.3),
        ),
        borderRadius: BorderRadius.circular(context.w(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Create Patient Account', 'إنشاء حساب المريض'),
            style: TextStyle(
              fontSize: context.sp(16),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0E3E3B),
            ),
          ),
          SizedBox(height: context.h(12)),
          Text(
            tr(
                'Complete the fields below to set up your patient account before accepting the invitation.',
                'أكمل الحقول أدناه لإعداد حساب المريض قبل قبول الدعوة.'),
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: context.sp(12),
            ),
          ),
          SizedBox(height: context.h(16)),

          // Name
          Text(
            tr('Full Name', 'الاسم الكامل'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: context.sp(14),
              color: const Color(0xFF2E5753),
              letterSpacing: context.sp(-0.2),
            ),
          ),
          SizedBox(height: context.h(8)),
          FieldWrapper(
            icon: Icons.person,
            child: CustomTextForm(
              textEditingController: _nameController,
              hintText: tr('Enter your full name', 'أدخل اسمك الكامل'),
              validator: (v) => null,
            ),
          ),

          SizedBox(height: context.h(12)),

          // Email if needed
          if (_invitationDetails?.patientEmail == null) ...[
            Text(
              tr('Email Address', 'البريد الإلكتروني'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: context.sp(14),
                color: const Color(0xFF2E5753),
                letterSpacing: context.sp(-0.2),
              ),
            ),
            SizedBox(height: context.h(8)),
            FieldWrapper(
              icon: Icons.email,
              child: CustomTextForm(
                textEditingController: _emailFallbackController,
                hintText: tr('example@mail.com', 'example@mail.com'),
                textInputType: TextInputType.emailAddress,
                validator: (v) => null,
              ),
            ),
            SizedBox(height: context.h(12)),
          ] else
            ...[
              Container(
                padding: EdgeInsets.all(context.w(12)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: AppColors.borderColor.withOpacity(.5)),
                  borderRadius: BorderRadius.circular(context.w(8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Colors.grey),
                    SizedBox(width: context.w(8)),
                    Expanded(
                      child: Text(
                        _invitationDetails!.patientEmail!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(12)),
            ],

          // Password
          Text(
            tr('Password', 'كلمة المرور'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: context.sp(14),
              color: const Color(0xFF2E5753),
              letterSpacing: context.sp(-0.2),
            ),
          ),
          SizedBox(height: context.h(8)),
          FieldWrapper(
            icon: Icons.lock_outline_rounded,
            child: CustomTextForm(
              textEditingController: _passwordController,
              hintText: _isAr ? '••••••••' : '••••••••',
              secure: true,
              validator: (v) => null,
            ),
          ),

          SizedBox(height: context.h(12)),

          // Confirm Password
          Text(
            tr('Confirm Password', 'تأكيد كلمة المرور'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: context.sp(14),
              color: const Color(0xFF2E5753),
              letterSpacing: context.sp(-0.2),
            ),
          ),
          SizedBox(height: context.h(8)),
          FieldWrapper(
            icon: Icons.lock_outline_rounded,
            child: CustomTextForm(
              textEditingController: _confirmPasswordController,
              hintText: _isAr ? '••••••••' : '••••••••',
              secure: true,
              validator: (v) => null,
            ),
          ),

          SizedBox(height: context.h(16)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreatingAccount ? null : _createPatientAccount,
              icon: _isCreatingAccount
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.person_add),
              label: Text(
                _isCreatingAccount ? tr(
                    'Creating account...', 'جارٍ إنشاء الحساب...') : tr(
                    'Create Account', 'إنشاء الحساب'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: context.h(16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _invitationCubit,
      child: Scaffold(
        backgroundColor: Colors.white,
        // خلينا نسمح للـ body بالتمدد مع الكيبورد
        resizeToAvoidBottomInset: true,
        body: BlocListener<InvitationCubit, InvitationState>(
          listener: (context, state) async {
            if (state is InvitationFailure) {
              showErrorDialog(
                context: context,
                error: state.errorMessage,
                title: "Error",
              );
              if (_isFetchingInvite) {
                setState(() => _isFetchingInvite = false);
              }
            } else if (state is InvitationAccepted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invitation accepted successfully ✅'),
                  backgroundColor: Colors.green,
                ),
              );
              // اعتبر أن المريض أتم خطوة الدعوة/إنشاء الحساب مرة واحدة على الأقل
              await SharedPrefsHelper.saveBool('patientOnboarded', true);

              // لو عندنا patientUid على الجهاز ⇒ المريض بالفعل عامل لوجين
              final hasLocalPatient = _patientUid != null;

              if (hasLocalPatient) {
                // إبقى على الجلسة الحالية وادخل مباشرة على الصفحة الرئيسية للمريض
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.patientMain,
                  (route) => false,
                );
              } else {
                // فى الحالات اللى بيتعمل فيها الحساب من شاشة الدعوة قبل اللوجين
                SharedPrefsHelper.remove("patientUid");
                SharedPrefsHelper.remove("userId");
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            } else if (state is InvitationRejected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invitation rejected'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.pop(context);
            } else if (state is InvitationSuccess) {
              setState(() {
                _invitationDetails = state.invitation;
                _isFetchingInvite = false;
              });
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery
                  .of(context)
                  .viewInsets
                  .bottom,
            ),
            child: BlocBuilder<InvitationCubit, InvitationState>(
              builder: (context, state) {
                return Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -context.w(430) * 0.25,
                      left: -context.w(430) * 0.15,
                      child: DecorCircle(size: context.w(430) * 0.7),
                    ),
                    Positioned(
                      bottom: -context.w(430) * 0.3,
                      right: -context.w(430) * 0.2,
                      child: DecorCircle(size: context.w(430) * 0.9),
                    ),

                    // Content
                    SafeArea(
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: context.h(40)),
                              Text(
                                tr('Accept Invitation', 'قبول الدعوة'),
                                style: TextStyle(
                                  color: const Color(0xFF0E3E3B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: context.sp(28),
                                ),
                              ),
                              SizedBox(height: context.h(6)),
                              Text(
                                tr('Enter your invitation code to join',
                                    'أدخل كود الدعوة للانضمام'),
                                style: TextStyle(
                                  color: const Color(0xFF7EA9A3),
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.sp(14),
                                ),
                              ),
                              SizedBox(height: context.h(50)),

                              // Card with form
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.w(18),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.w(18),
                                    vertical: context.h(20),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color:
                                      AppColors.borderColor.withOpacity(.5),
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(context.w(22)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 18,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    autovalidateMode: AutovalidateMode
                                        .onUnfocus,
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('Invitation Details',
                                              'تفاصيل الدعوة'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: context.sp(18),
                                            color: const Color(0xFF0E3E3B),
                                            letterSpacing: context.sp(-0.3),
                                          ),
                                        ),
                                        SizedBox(height: context.h(18)),

                                        // Invitation Code
                                        Text(
                                          tr('Invitation Code', 'كود الدعوة'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: context.sp(14),
                                            color: const Color(0xFF2E5753),
                                            letterSpacing: context.sp(-0.2),
                                          ),
                                        ),
                                        SizedBox(height: context.h(8)),
                                        FieldWrapper(
                                          icon: Icons.vpn_key,
                                          child: CustomTextForm(
                                            textEditingController:
                                            _codeController,
                                            validator: (v) {
                                              if (v == null || v
                                                  .trim()
                                                  .isEmpty) {
                                                return tr(
                                                    'Please enter invitation code',
                                                    'يرجى إدخال كود الدعوة');
                                              }
                                              return null;
                                            },
                                            hintText: tr(
                                                'Enter code', 'أدخل الكود'),
                                          ),
                                        ),

                                        SizedBox(height: context.h(16)),

                                        // Fetch button
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _isFetchingInvite
                                                ? null
                                                : () {
                                              final code = _codeController.text
                                                  .trim();
                                              if (code.isEmpty) {
                                                showErrorDialog(
                                                  context: context,
                                                  error: tr(
                                                      "Please enter invitation code first",
                                                      "يرجى إدخال كود الدعوة أولاً"),
                                                  title: tr("Missing code",
                                                      "الكود مفقود"),
                                                );
                                                return;
                                              }
                                              _fetchInvitation(
                                                  code.toUpperCase());
                                            },
                                            icon: _isFetchingInvite
                                                ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                                : const Icon(Icons.search),
                                            label: Text(
                                              _isFetchingInvite ? tr(
                                                  'Looking up...',
                                                  'جارٍ البحث...') : tr(
                                                  'Fetch Invitation Details',
                                                  'جلب تفاصيل الدعوة'),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: context.h(16)),
                                              side: const BorderSide(
                                                  color: AppColors
                                                      .primaryColor),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius
                                                    .circular(12),
                                              ),
                                            ),
                                          ),
                                        ),

                                        _buildInvitationDetails(),
                                        _buildAccountCreationForm(),

                                        SizedBox(height: context.h(24)),

                                        // Accept button
                                        SizedBox(
                                          width: double.infinity,
                                          child: CustomButton(
                                            onClick: _handleAcceptInvitation,
                                            text: tr("Accept Invitation",
                                                "قبول الدعوة"),
                                          ),
                                        ),

                                        SizedBox(height: context.h(12)),

                                        // Reject button
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: _handleRejectInvitation,
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: context.h(16)),
                                              side: const BorderSide(
                                                  color: AppColors
                                                      .primaryColor),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius
                                                    .circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              tr("Reject", "رفض"),
                                              style: TextStyle(
                                                color: AppColors.primaryColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: context.sp(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: context.h(16)),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.login,
                                  );
                                },
                                icon: const Icon(Icons.arrow_back),
                                label: Text(tr(
                                    'Back to Login', 'العودة لتسجيل الدخول')),
                              ),
                            ],
                          ),

                          if (state is InvitationLoading)
                            Positioned.fill(
                              child: AbsorbPointer(
                                absorbing: true,
                                child: Container(
                                  color: Colors.black.withOpacity(0.1),
                                  child: const Center(child: LoadingPage()),
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
