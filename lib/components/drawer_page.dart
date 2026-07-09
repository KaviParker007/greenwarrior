import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_version.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? menu;
  String? username;
  bool isSuperUser = true;
  bool isAttendanceExpanded = false; // Track if attendance submenu is expanded

  @override
  void initState() {
    super.initState();
    getMenu();
  }

  void getMenu() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      menu = prefs.getString("menu");
      username = prefs.getString("username");
    });
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("username");
    await prefs.remove("password");
    await prefs.remove("deviceId");
    await prefs.remove("userid");
    await prefs.remove("access_token");
    await prefs.remove("refresh_token");
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.grey.shade100,
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
                  Text(
                    "Welcome $username",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                    icon: Icons.qr_code_2,
                    title: "D2D",
                    selected: menu == "bin_collections",
                    onTap: () {
                      Navigator.pushReplacementNamed(
                          context, '/bin_collection');
                    },
                  ),
                ],
              ),
            ),

            /// ===== FOOTER =====
            const Divider(),

            buildMenuTile(
              icon: Icons.logout,
              title: "Logout",
              selected: false,
              onTap: logout,
              isLogout: true,
            ),

            const SizedBox(height: 10),
            const AppVersionText(),
            const SizedBox(height: 15),
          ],
        ),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selected
            ? Colors.green.withOpacity(0.15)
            : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout
              ? Colors.red
              : (selected ? Colors.green : Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight:
            selected ? FontWeight.w600 : FontWeight.w500,
            color: isLogout
                ? Colors.red
                : (selected ? Colors.green : Colors.black87),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget buildSubMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.only(left: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selected
            ? Colors.blue.withOpacity(0.15)
            : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          size: 20,
          color: selected ? Colors.green : Colors.black87,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
            selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.green : Colors.black87,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }


}