import 'package:flutter/material.dart';

import '../../config/screen_sizer/size_extension.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_listener_widget.dart';
import './family_activities_screen.dart';
import 'family_chat_screen.dart';
import 'family_dashboard.dart';
import 'family_profile_screen.dart';
import 'family_tracking_screen.dart';

class FamilyMainScreen extends StatefulWidget {
  const FamilyMainScreen({super.key});

  @override
  State<FamilyMainScreen> createState() => _FamilyMainScreenState();
}

class _FamilyMainScreenState extends State<FamilyMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FamilyDashboard(),
    const FamilyTrackingScreen(),
    const FamilyChatScreen(),
    const FamilyProfileScreen(),
    const FamilyActivitiesScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final isAr =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'en') == 'ar';
    String tr(String en, String ar) => isAr ? ar : en;

    return NotificationListenerWidget(
      showSnackBar: true,
      showDialog: true,
      onNotification: (notification) {
        // يمكنك إضافة منطق إضافي هنا عند استلام إشعار
        debugPrint('Received notification: ${notification.type}');
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightGradient,
        ),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.w(8),
              vertical: context.h(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, tr('Home', 'الرئيسية'),),
                _buildNavItem(
                    1, Icons.location_on, tr('Tracking', 'تتبع المريض')),
                _buildNavItem(4, Icons.psychology, tr('Activities', 'الأنشطة')),
                _buildNavItem(2, Icons.chat, tr('Chat', 'المحادثات')),
                _buildNavItem(3, Icons.person, tr('Profile', 'الملف الشخصي')),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(context.w(12)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(12),
          vertical: context.h(8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal50 : Colors.transparent,
          borderRadius: BorderRadius.circular(context.w(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.teal600 : AppTheme.gray500,
              size: context.sp(25),
            ),
            SizedBox(height: context.h(4)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.sp(12),
                  color: isSelected ? AppTheme.teal600 : AppTheme.gray500,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}