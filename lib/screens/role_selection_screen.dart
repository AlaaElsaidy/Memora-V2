import 'package:alzcare/config/router/routes.dart';
import 'package:alzcare/config/screen_sizer/size_extension.dart';
import 'package:alzcare/core/shared-prefrences/shared-prefrences-helper.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../main.dart' show appStateInstance;

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';
    String tr(String en, String ar) => isAr ? ar : en;

    return Scaffold(

      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.w(24)),
              child: Column(
                children: [
                  // Language switcher button (top right)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(
                        isAr ? Icons.language : Icons.translate,
                        color: AppTheme.teal600,
                        size: context.sp(35),
                      ),
                      tooltip: isAr ? 'English' : 'العربية',
                      onPressed: () {
                        if (appStateInstance != null) {
                          final newLocale = isAr
                              ? const Locale('en')
                              : const Locale('ar');
                          appStateInstance!.changeLanguage(newLocale);
                        }
                      },
                    ),
                  ),
                  // SizedBox(height: context.h(16)),

                  // Logo
                  // Container(
                  //   width: context.w(80),
                  //   height: context.h(80),
                  //   decoration: const BoxDecoration(
                  //     gradient: AppTheme.tealGradient,
                  //     shape: BoxShape.circle,
                  //   ),
                  //   child: Icon(
                  //     Icons.psychology,
                  //     size: context.sp(40),
                  //     color: Colors.white,
                  //   ),
                  // ),
                  Image.asset(
                      "assets/images/png/splash.png", height: context.h(200),
                      width: context.w(300),
                      fit: BoxFit.cover),
                  // SizedBox(height: context.h(24)),
                  //
                  // Title
                  // Text(
                  //   'Memora',
                  //   style: TextStyle(
                  //     fontSize: context.sp(32),
                  //     fontWeight: FontWeight.bold,
                  //     color: AppTheme.teal900,
                  //   ),
                  // ),
                  // SizedBox(height: context.h(8)),
                  // Text(
                  //   tr('Compassionate Care for Alzheimer\'s Patients',
                  //       'رعاية رحيمة لمرضى الزهايمر'),
                  //   textAlign: TextAlign.center,
                  //   style: TextStyle(
                  //     fontSize: context.sp(16),
                  //     color: AppTheme.teal600,
                  //   ),
                  // ),
                  // SizedBox(height: context.h(28)),

                  // Role Selection Card
                  Container(
                    constraints: BoxConstraints(maxWidth: context.w(400)),
                    padding: EdgeInsets.all(context.w(32)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(context.w(24)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.teal500.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          tr('Select Your Role', 'اختر دورك في التطبيق'),
                          style: TextStyle(
                            fontSize: context.sp(24),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.teal900,
                          ),
                        ),
                        SizedBox(height: context.h(24)),

                        // Patient Button
                        _RoleButton(
                          icon: Icons.person,
                          label: tr('Patient Portal', 'واجهة المريض'),
                          onPressed: () {
                            SharedPrefsHelper.saveString(
                                'selectedRole', 'patient');
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                        ),
                        SizedBox(height: context.h(16)),

                        // Doctor Button
                        _RoleButton(
                          icon: Icons.medical_services,
                          label: tr('Doctor Portal', 'واجهة الطبيب'),
                          onPressed: () {
                            SharedPrefsHelper.saveString(
                                'selectedRole', 'doctor');
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                        ),
                        SizedBox(height: context.h(16)),

                        // Family Button
                        _RoleButton(
                          icon: Icons.family_restroom,
                          label: tr('Family Member Portal', 'واجهة القريب'),
                          onPressed: () {
                            SharedPrefsHelper.saveString(
                                'selectedRole', 'family');
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _RoleButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.h(56),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.teal500,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.w(16)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.sp(22)),
            SizedBox(width: context.w(8)),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
