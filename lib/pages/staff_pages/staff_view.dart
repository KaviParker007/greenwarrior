import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:greenwarrior/components/buttons.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;
import "package:greenwarrior/pages/login.dart";
import "package:greenwarrior/pages/staff_pages/edit_staff.dart";

class StaffView extends StatefulWidget {
  final int userId;
  const StaffView({
    super.key,
    required this.userId,
  });

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  Map staff = {};
  bool isLoggedIn = false;
  String? username;
  String? password;

  void errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void deactivateStaff(Map staff) async {
    setState(() {
      isLoading = true;
    });
    var uri = Uri.parse("$baseUrl/test/employee/${staff['id']}/");
    var headers = {'Content-Type': 'application/json'};
    staff['is_active'] = false;
    staff.remove("image");
    var bodyParams = jsonEncode(staff);
    var response = await http.put(
      uri,
      headers: headers,
      body: bodyParams,
    );
    if (response.statusCode == 200) {
      Navigator.pop(context);
      Navigator.pushNamed(context, "/staff_list");
    } else {
      errorMsg("Unable to Deactivate user");
    }
    setState(() {
      isLoading = false;
    });
  }

  void editStaff(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStaffPage(
          userId: id,
          staffViewRedirect: true,
        ),
      ),
    );
  }

  void getUser(int id) async {
    setState(() {
      isLoading = true;
    });
    var uri = Uri.parse("$baseUrl/test/employee/$id/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'Authorization': auth};
    var response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      setState(() {
        staff = jsonDecode(response.body);
      });
    } else {
      errorMsg("Unable to find User");
      Navigator.pop(context);
      Navigator.pushNamed(context, "/staff_list");
    }

    setState(() {
      isLoading = false;
    });
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "vehicles");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    getUser(widget.userId);
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : isLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Scaffold(
                appBar: AppBar(
                  // PROFILE NAME
                  title: Text(staff['name'].toString()),
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton(
                      onPressed: () {
                        editStaff(staff['id']);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsets.all(15),
                  children: [
                    // PROFILE IMAGE
                    CircleAvatar(
                      radius: 80,
                      child: ClipOval(
                        child: staff['image'] != null
                            ? Image.network(
                                "${staff['image']}",
                                width: 160,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                "assets/images/default-user.png",
                                width: 160,
                                height: 160,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        child: Column(
                          children: [
                            // SUPERUSER, ZONAL MANAGER, MECHANIC
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (staff['is_superuser'] ?? true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Superuser",
                                      textColor: Colors.black54,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                      fontsize: 12,
                                      verticalPadding: -6,
                                    ),
                                  ),
                                if (staff['is_zonal_manager'] ?? true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Zonal Manager",
                                      textColor: Colors.white,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .inversePrimary,
                                      fontsize: 12,
                                      verticalPadding: -6,
                                    ),
                                  ),
                                if (staff['is_mechanic'] ?? true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Pill(
                                      text: "Mechanic",
                                      textColor: Colors.white,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                      fontsize: 12,
                                      verticalPadding: -6,
                                    ),
                                  ),
                              ],
                            ),

                            // EMPLOYEE ID
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Employee Id"),
                                Text(
                                  staff["employee_id"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // CONTACT
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const LabelText(text: "Contact"),
                                Text(
                                  staff["contact"].toString(),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // ADDRESS
                            const LabelText(text: "Address"),
                            Text(
                              staff['address'].toString(),
                              style: const TextStyle(fontSize: 17),
                            ),

                            // REMARK
                            if (staff['remark'].toString().isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 15),
                                  const LabelText(text: "Remark"),
                                  Text(
                                    staff['remark'].toString(),
                                    style: const TextStyle(fontSize: 17),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // DEACTIVATE BUTTON
                    const SizedBox(height: 10),
                    DangerButton(
                      text: "Deactivate User",
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  deactivateStaff(staff);
                                },
                                child: const Text(
                                  "Deactivate",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  "Close",
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              )
                            ],
                            title: const Text(
                              "Deactivate User",
                              style: TextStyle(color: Colors.red),
                            ),
                            content: Text(
                              "Are your sure, you want to deactivate ${staff['name']}?",
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
  }
}
