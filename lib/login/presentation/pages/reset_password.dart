import 'package:alzcare/config/router/routes.dart';
import 'package:alzcare/config/screen_sizer/size_extension.dart';
import 'package:alzcare/config/shared/valdation/validator.dart';
import 'package:alzcare/config/shared/widgets/custom-button.dart';
import 'package:alzcare/config/shared/widgets/custom-text-form.dart';
import 'package:alzcare/config/shared/widgets/decore-circle.dart';
import 'package:alzcare/config/shared/widgets/error-dialoge.dart';
import 'package:alzcare/config/shared/widgets/field-wrapper.dart';
import 'package:alzcare/config/shared/widgets/loading.dart';
import 'package:alzcare/config/utilis/app_colors.dart';
import 'package:alzcare/core/supabase/auth-service.dart';
import 'package:alzcare/login/data/reset_password_repo.dart';
import 'package:alzcare/login/presentation/cubit/reset_password_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isAr =>
      (Localizations
          .maybeLocaleOf(context)
          ?.languageCode ?? 'en') == 'ar';

  String tr(String en, String ar) => _isAr ? ar : en;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.w(20)),
            ),
            title: Text(
              tr('Check your email', 'تحقق من بريدك الإلكتروني'),
              textAlign: TextAlign.center,
            ),
            content: Text(
              tr(
                'We sent a link to reset your password.',
                'تم إرسال رابط لإعادة تعيين كلمة المرور.',
              ),
              textAlign: TextAlign.center,
            ),
            actions: [
              CustomButton(
                onClick: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                        (route) => false,
                  );
                },
                text: tr('Back to login', 'العودة لتسجيل الدخول'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ResetPasswordCubit(ResetPasswordRepo(AuthService())),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: BlocListener<ResetPasswordCubit, ResetPasswordState>(
          listener: (context, state) {
            if (state is ResetPasswordFailure) {
              showErrorDialog(
                context: context,
                error: state.errorMessage,
                title: tr('Reset failed', 'فشل إعادة التعيين'),
              );
            }
            if (state is ResetPasswordSuccess) {
              _showSuccessDialog();
            }
          },
          child: BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
            builder: (context, state) {
              final isLoading = state is ResetPasswordLoading;
              return Stack(
                children: [
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
                  SafeArea(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: context.h(16)),
                            Text(
                              tr('Reset Password', 'إعادة تعيين كلمة المرور'),
                              style: TextStyle(
                                color: const Color(0xFF0E3E3B),
                                fontWeight: FontWeight.w800,
                                fontSize: context.sp(28),
                              ),
                            ),
                            SizedBox(height: context.h(6)),
                            Text(
                              tr(
                                'Enter your email to get a reset link',
                                'أدخل بريدك للحصول على رابط إعادة التعيين',
                              ),
                              style: TextStyle(
                                color: const Color(0xFF7EA9A3),
                                fontWeight: FontWeight.w600,
                                fontSize: context.sp(14),
                              ),
                            ),
                            SizedBox(height: context.h(50)),
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
                                  autovalidateMode: AutovalidateMode.onUnfocus,
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr('Account email',
                                            'البريد الإلكتروني'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: context.sp(18),
                                          color: const Color(0xFF0E3E3B),
                                          letterSpacing: context.sp(-0.3),
                                        ),
                                      ),
                                      SizedBox(height: context.h(18)),
                                      Text(
                                        tr('Email Address',
                                            'البريد الإلكتروني'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: context.sp(14),
                                          color: const Color(0xFF2E5753),
                                          letterSpacing: context.sp(-0.2),
                                        ),
                                      ),
                                      SizedBox(height: context.h(8)),
                                      FieldWrapper(
                                        icon: Icons.email_outlined,
                                        child: CustomTextForm(
                                          maxLength: 40,
                                          textEditingController:
                                          _emailController,
                                          validator: (v) => emailValidator(v),
                                          hintText: tr('example@mail.com',
                                              'example@mail.com'),
                                          textInputType:
                                          TextInputType.emailAddress,
                                        ),
                                      ),
                                      SizedBox(height: context.h(20)),
                                      SizedBox(
                                        width: double.infinity,
                                        child: CustomButton(
                                          onClick: () async {
                                            if (isLoading) return;
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await BlocProvider.of<
                                                  ResetPasswordCubit>(
                                                  context)
                                                  .sendResetEmail(
                                                  email: _emailController
                                                      .text);
                                            }
                                          },
                                          text: isLoading
                                              ? tr(
                                              'Loading...', 'جارٍ التحميل...')
                                              : tr('Send reset link',
                                              'أرسل رابط إعادة التعيين'),
                                        ),
                                      ),
                                      SizedBox(height: context.h(12)),
                                      Center(
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.pushNamedAndRemoveUntil(
                                              context,
                                              AppRoutes.login,
                                                  (route) => false,
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            tr('Back to login',
                                                'العودة لتسجيل الدخول'),
                                            style: TextStyle(
                                              color: AppColors.primaryColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: context.sp(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isLoading)
                          Positioned.fill(
                            child: AbsorbPointer(
                              absorbing: true,
                              child: Container(
                                color: Colors.black.withOpacity(0.1),
                                child: const Center(child: LoadingPage()),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

