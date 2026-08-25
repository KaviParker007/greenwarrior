import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_version.dart';

/// The drawer entries that can be the active screen.
///
/// Each screen declares its own entry when it builds the drawer, so exactly one
/// item is ever highlighted.
enum DrawerMenu { dashboard, collections }

class AppDrawer extends StatefulWidget {
  /// The entry belonging to the screen currently showing this drawer.
  ///
  /// Required on purpose: the highlight used to be driven by a persisted
  /// `menu` preference that each screen had to remember to write, which meant a
  /// screen that forgot left the previous item highlighted. Passing it in makes
  /// the active item a compile-time obligation, and it stays correct for direct
  /// navigation, replacement and back navigation alike because it is derived
  /// from whichever screen is actually on screen.
  final DrawerMenu activeMenu;

  const AppDrawer({super.key, required this.activeMenu});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? username;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final displayName = await AuthService.currentDisplayName();
    if (!mounted) return;
    setState(() => username = displayName);
  }

  /// Blacklists the refresh token server side, then clears the local session.
  ///
  /// The session is cleared even if the network call fails, so a signed-out user
  /// is never left stuck on an authenticated screen.
  Future<void> logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    await AuthService.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login_page',
      (route) => false,
    );
  }

  /// Replaces the current screen, unless it is already the active one.
  ///
  /// Re-navigating to the screen you are already on would rebuild it for no
  /// reason and refetch its data.
  void _openIfNotActive(DrawerMenu target, String routeName) {
    if (widget.activeMenu == target) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    // The background lives on the Drawer's own Material rather than on an
    // intermediate Container, so the ListTiles below can paint their tile
    // colors and ink splashes on top of it instead of behind it.
    return Drawer(
      backgroundColor: Colors.grey.shade100,
      child: Column(
        children: [

          /// ===== HEADER WITH GRADIENT =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration:  BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade400,
                  Colors.green.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  backgroundImage:
                  AssetImage("assets/images/default-user.png"),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Welcome ${username ?? ''}".trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ===== MENU ITEMS =====
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              children: [

                buildMenuTile(
                  icon: Icons.dashboard_rounded,
                  title: "D2D Dashboard",
                  selected: widget.activeMenu == DrawerMenu.dashboard,
                  onTap: () => _openIfNotActive(
                    DrawerMenu.dashboard,
                    '/d2d_dashboard',
                  ),
                ),

                buildMenuTile(
                  icon: Icons.qr_code_2,
                  title: "D2D",
                  selected: widget.activeMenu == DrawerMenu.collections,
                  onTap: () => _openIfNotActive(
                    DrawerMenu.collections,
                    '/bin_collection',
                  ),
                ),
              ],
            ),
          ),

          /// ===== FOOTER =====
          const Divider(),

          buildMenuTile(
            icon: Icons.logout,
            title: _isLoggingOut ? "Signing out..." : "Logout",
            selected: false,
            onTap: logout,
            isLogout: true,
          ),

          const SizedBox(height: 10),
          const AppVersionText(),
          const SizedBox(height: 15),
        ],
      ),
    );
  }


  Widget buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool selected,
    bool isLogout = false,
  }) {
    final Color contentColor = isLogout
        ? Colors.red
        : (selected ? Colors.green : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: contentColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight:
            selected ? FontWeight.w600 : FontWeight.w500,
            color: contentColor,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        // Let the ListTile paint its own highlight so it layers correctly
        // with the ink splash; `shape` clips it to the rounded corners.
        tileColor:
            selected ? Colors.green.withValues(alpha: 0.15) : null,
        onTap: onTap,
      ),
    );
  }
}
