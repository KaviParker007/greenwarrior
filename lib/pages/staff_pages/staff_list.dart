import 'dart:convert';
import "package:flutter/material.dart";
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/pages/staff_pages/add_staff.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:greenwarrior/config.dart';
import 'package:http/http.dart' as http;
import 'package:badges/badges.dart' as badges;
import 'package:greenwarrior/pages/staff_pages/edit_staff.dart';
import 'package:greenwarrior/pages/staff_pages/staff_view.dart';

class StaffListBuilder extends StatefulWidget {
  final List staffs;
  final String baseUrl;
  const StaffListBuilder({
    super.key,
    required this.staffs,
    required this.baseUrl,
  });

  @override
  State<StaffListBuilder> createState() => _StaffListBuilderState();
}

class _StaffListBuilderState extends State<StaffListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void editStaff(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditStaffPage(userId: id)),
    );
  }

  void staffView(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StaffView(userId: id)),
    );
  }

  void deactivateStaff(Map staff) async {
    setState(() {
      isLoading = true;
    });
    var uri = Uri.parse("${widget.baseUrl}/test/employee/${staff['id']}/");
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: const Text("Unable to Deactivate user"),
        duration: const Duration(seconds: 10),
      ));
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.staffs.length,
            itemBuilder: (context, index) {
              final staff = widget.staffs[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    // EDIT BUTTON
                    SlidableAction(
                      onPressed: (_) => editStaff(staff['id']),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icons.edit,
                      label: 'Edit',
                    ),

                    // DEACTIVATE BUTTON
                    SlidableAction(
                      onPressed: (_) => showDialog(
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
                                )),
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
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      icon: Icons.person_off_rounded,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      label: 'Deactivate',
                      // spacing: 8,
                    )
                  ],
                ),
                child: Card(
                  child: badges.Badge(
                    showBadge: staff['is_superuser'] == true,
                    badgeContent: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 15,
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: Colors.green,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: ClipOval(
                          child: staff['image'] != null
                              ? Image.network(
                                  "${widget.baseUrl}${staff['image']}",
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "assets/images/default-user.png",
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      title: Text(
                        staff['name'],
                        // style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(staff['employee_id']),
                          Text(staff['contact']),
                        ],
                      ),
                      onTap: () {
                        staffView(staff['id']);
                      },
                    ),
                  ),
                ),
              );
            });
  }
}

class StaffList extends StatefulWidget {
  const StaffList({super.key});

  @override
  State<StaffList> createState() => _StaffListState();
}

class _StaffListState extends State<StaffList> {
  bool isLoggedIn = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List staffs = [];

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getStaffList() async {
    var uri = Uri.parse("$baseUrl/drf-staff-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    try {
      var response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'filter': 'active'}),
      );
      if (response.statusCode == 200) {
        setState(() {
          staffs = jsonDecode(response.body);
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text("500 - Server Error"),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      // print('Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(e.toString()),
        duration: const Duration(seconds: 10),
      ));
    }
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "staffs");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getStaffList();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: const Text("Staff List"),
                actions: [
                  IconButton(
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: CustomSearchDelegate(
                            staffs: staffs, baseUrl: baseUrl),
                      );
                    },
                    icon: const Icon(Icons.search),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "active",
                        child: Text("Active"),
                      ),
                      const PopupMenuItem(
                        value: "inactive",
                        child: Text("In Active"),
                      ),
                    ],
                    icon: const Icon(Icons.filter_list_rounded),
                    onSelected: (String filter) {
                      print(filter);
                    },
                  )
                ],
              ),
              drawer: const AppDrawer(),
              body: Visibility(
                visible: staffs != [],
                replacement: const Center(
                  child: CircularProgressIndicator(),
                ),
                child: RefreshIndicator(
                  onRefresh: getStaffList,
                  child: StaffListBuilder(staffs: staffs, baseUrl: baseUrl),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddStaffPage()),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}

class CustomSearchDelegate extends SearchDelegate {
  List staffs = [];
  final String baseUrl;
  CustomSearchDelegate({required this.staffs, required this.baseUrl});
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = "";
        },
        icon: const Icon(Icons.clear),
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    String searchQuery = query.toLowerCase();
    List searchList = [];
    Set<int> uniqueIds = {};
    if (searchQuery.isEmpty) {
      return StaffListBuilder(staffs: staffs, baseUrl: baseUrl);
    } else {
      for (var staff in staffs) {
        for (var searchKey in ['name', 'employee_id', 'contact']) {
          if (staff[searchKey].toString().toLowerCase().contains(searchQuery)) {
            if (!uniqueIds.contains(staff['id'])) {
              searchList.add(staff);
              uniqueIds.add(staff['id']);
            }
          }
        }
      }
      return StaffListBuilder(staffs: searchList, baseUrl: baseUrl);
    }
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return StaffListBuilder(staffs: staffs, baseUrl: baseUrl);
  }
}
