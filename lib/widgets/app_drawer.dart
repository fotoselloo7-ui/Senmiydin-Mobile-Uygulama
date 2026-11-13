import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/brand_assets.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'common.dart';

/// Production-ready side drawer matching the approved SenMiydin visual reference.
///
/// Features:
/// - 75% screen width with 32px rounded right border.
/// - Soft organic blue/lilac wave accents on top-right and bottom.
/// - Purple/lilac brand logo at the top.
/// - Frosted floating user profile card with glowing avatar halo, name,
///   username, registered city (secondary metadata), and chevron button.
/// - Outlined icon family with soft rounded-square containers (42x42px).
/// - Dynamic selected state (soft lilac background with 4px left purple bar).
/// - Footer with brand tagline and origami paper plane + dashed heart trail.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.currentRoute, this.onProfile});

  /// Currently active route name (e.g. '/home', '/encounters').
  /// Only matches if an actual secondary route is active. If opened from home,
  /// none of the secondary items are falsely marked as active.
  final String? currentRoute;

  /// Callback when user profile card is tapped.
  final VoidCallback? onProfile;

  static const _menuItems = [
    _DrawerItemDef(
      title: 'Karşılaşmalarım',
      icon: Icons.favorite_border_rounded,
      route: '/encounters',
      isBrandAccent: true,
    ),
    _DrawerItemDef(
      title: 'Mektuplarım',
      icon: Icons.mail_outline_rounded,
      route: '/my-letters',
      isBrandAccent: true,
    ),
    _DrawerItemDef(
      title: 'Kaydedilenler',
      icon: Icons.bookmark_border_rounded,
      route: '/saved',
    ),
    _DrawerItemDef(
      title: 'Bildirimler',
      icon: Icons.notifications_none_rounded,
      route: '/notifications',
      hasBadge: true,
    ),
    _DrawerItemDef(
      title: 'İlgi Alanlarım',
      icon: Icons.category_outlined,
      route: '/interests',
    ),
    _DrawerItemDef(
      title: 'Filtreler',
      icon: Icons.tune_rounded,
      route: '/filters',
    ),
    _DrawerItemDef(
      title: 'Ayarlar',
      icon: Icons.settings_outlined,
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final width = math.min(360.0, MediaQuery.sizeOf(context).width * 0.76);

    return Drawer(
      width: width,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: AppColors.navy.withValues(alpha: 0.16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background soft organic wave decorations
          Positioned(
            top: 0,
            right: 0,
            width: width * 0.65,
            height: 220,
            child: const CustomPaint(painter: _TopWavePainter()),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: const CustomPaint(painter: _BottomWavePainter()),
          ),

          // Main drawer content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Logo Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      BrandAssets.logoPrimaryLight,
                      height: 38,
                      fit: BoxFit.contain,
                      semanticLabel: 'SenMiydin?',
                    ),
                  ),
                ),

                // 2. Profile Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: _DrawerProfileCard(
                    user: store.me,
                    onTap: () {
                      Navigator.pop(context);
                      if (onProfile != null) {
                        onProfile!();
                      } else {
                        openPage(context, '/profile', store.me.id);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Navigation Menu Items (Scrollable fallback for small devices)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < _menuItems.length; i++) ...[
                          if (i == 3 || i == 5)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF1F3F9),
                              ),
                            ),
                          _DrawerMenuItem(
                            def: _menuItems[i],
                            isSelected: currentRoute == _menuItems[i].route,
                            badgeCount:
                                _menuItems[i].hasBadge && store.connected
                                ? store.unreadNotifications
                                : 0,
                            onTap: () {
                              Navigator.pop(context);
                              if (currentRoute != _menuItems[i].route) {
                                openPage(context, _menuItems[i].route);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 4. Footer with Brand Tagline & Paper Plane
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Brand text
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SenMiydin?',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF6B21A8),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Güzel tesadüflere yer aç.',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Origami Paper Plane & Heart Trail
                      const SizedBox(
                        width: 92,
                        height: 48,
                        child: CustomPaint(
                          painter: _HeartTrailPaperPlanePainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItemDef {
  const _DrawerItemDef({
    required this.title,
    required this.icon,
    required this.route,
    this.isBrandAccent = false,
    this.hasBadge = false,
  });

  final String title;
  final IconData icon;
  final String route;
  final bool isBrandAccent;
  final bool hasBadge;
}

/// Floating profile card inside the drawer with subtle gradient border and halo.
class _DrawerProfileCard extends StatelessWidget {
  const _DrawerProfileCard({required this.user, required this.onTap});

  final dynamic user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profilimi aç',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF9F7FD)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEBE6F8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C20D4).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with multi-color pastel glowing accent ring
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF8A6DFB),
                        Color(0xFF38BDF8),
                        Color(0xFFF472B6),
                        Color(0xFF8A6DFB),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: ClipOval(child: Avatar(user, size: 50)),
                  ),
                ),

                const SizedBox(width: 12),

                // Name and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${user.handle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              user.city as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Real chevron icon inside soft circular container (NO ASCII > or ›)
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF1EEF9),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized Drawer Menu Row with active capsule state and soft icon container.
class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.def,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _DrawerItemDef def;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    const activePurple = Color(0xFF7C20D4);
    const activeTextPurple = Color(0xFF2E1065);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: def.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF6EFFF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Left vertical bar on active item
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 24,
                      margin: const EdgeInsets.only(left: 3, right: 8),
                      decoration: BoxDecoration(
                        color: activePurple,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(width: 15),

                  // Soft icon box container (42x42px, radius 13)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEDDDFD)
                          : const Color(0xFFF3F5FC),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Icon(
                        def.icon,
                        size: 21,
                        color: isSelected
                            ? activePurple
                            : (def.isBrandAccent
                                  ? const Color(0xFF6B21A8)
                                  : const Color(0xFF334155)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Title text
                  Expanded(
                    child: Text(
                      def.title,
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected ? activeTextPurple : AppColors.navy,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),

                  // Optional notification badge
                  if (badgeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.encounterPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the delicate pastel organic wave in the top-right corner.
class _TopWavePainter extends CustomPainter {
  const _TopWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer soft lilac wave
    final path1 = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w * 0.15, h * 0.45, w * 0.7, h * 0.75)
      ..quadraticBezierTo(w * 0.9, h * 0.85, w, h * 0.8)
      ..lineTo(w, 0)
      ..close();

    final paint1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0x33A855F7), // Soft brand lilac
          Color(0x2238BDF8), // Soft functional sky
          Color(0x00FFFFFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path1, paint1);

    // Inner bright wave contour
    final path2 = Path()
      ..moveTo(w * 0.3, 0)
      ..quadraticBezierTo(w * 0.45, h * 0.35, w * 0.85, h * 0.55)
      ..lineTo(w, h * 0.5)
      ..lineTo(w, 0)
      ..close();

    final paint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
        colors: [Color(0x28C084FC), Color(0x1038BDF8)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the pastel bottom wave bands (cyan, lilac, purple).
class _BottomWavePainter extends CustomPainter {
  const _BottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Cyan soft wave on the left
    final cyanPath = Path()
      ..moveTo(0, h * 0.35)
      ..quadraticBezierTo(w * 0.22, h * 0.2, w * 0.45, h * 0.55)
      ..quadraticBezierTo(w * 0.6, h * 0.75, w * 0.7, h)
      ..lineTo(0, h)
      ..close();

    final cyanPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0x3838BDF8), Color(0x18BAE6FD)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(cyanPath, cyanPaint);

    // Lilac wave in the center/right
    final lilacPath = Path()
      ..moveTo(w * 0.2, h)
      ..quadraticBezierTo(w * 0.45, h * 0.4, w * 0.75, h * 0.45)
      ..quadraticBezierTo(w * 0.9, h * 0.48, w, h * 0.4)
      ..lineTo(w, h)
      ..close();

    final lilacPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topRight,
        colors: [Color(0x32A855F7), Color(0x18C084FC)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(lilacPath, lilacPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws the origami paper plane and dashed heart trail.
class _HeartTrailPaperPlanePainter extends CustomPainter {
  const _HeartTrailPaperPlanePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dashed heart loop trail
    final trailPaint = Paint()
      ..color = const Color(0xFFA78BFA).withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Starts at bottom-left:
    path.moveTo(4, 44);
    // Sweeps up towards left heart lobe:
    path.cubicTo(16, 42, 22, 28, 28, 24);
    path.cubicTo(31, 21, 35, 23, 37, 26);
    // Dips into center cleft:
    path.cubicTo(39, 29, 41, 31, 43, 26);
    // Rises to right lobe:
    path.cubicTo(45, 21, 50, 21, 53, 25);
    // Curves down and loops across:
    path.cubicTo(56, 30, 48, 42, 36, 38);
    // Arcs upward-right towards the plane:
    path.cubicTo(26, 35, 46, 44, 58, 21);

    // Render dashed segments along the path
    const dashLength = 2.8;
    const dashSpace = 3.2;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashLength, metric.length - distance);
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, trailPaint);
        distance += dashLength + dashSpace;
      }
    }

    // 2. Origami Paper Plane at (x: 58, y: 20)
    canvas.save();
    canvas.translate(58, 20);
    canvas.rotate(-0.38); // Angled up-right ~ -22 degrees

    // Top wing facet (lighter lilac)
    final topWing = Path()
      ..moveTo(18, 0)
      ..lineTo(0, -9)
      ..lineTo(4, 0)
      ..close();
    canvas.drawPath(topWing, Paint()..color = const Color(0xFFA855F7));

    // Main wing facet (vibrant brand purple)
    final mainWing = Path()
      ..moveTo(18, 0)
      ..lineTo(0, 9)
      ..lineTo(4, 0)
      ..close();
    canvas.drawPath(mainWing, Paint()..color = const Color(0xFF9333EA));

    // Center fold underbelly crease (deeper purple)
    final crease = Path()
      ..moveTo(4, 0)
      ..lineTo(1, 4)
      ..lineTo(9, 0)
      ..close();
    canvas.drawPath(crease, Paint()..color = const Color(0xFF7E22CE));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
