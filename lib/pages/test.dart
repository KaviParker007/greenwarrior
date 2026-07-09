import 'dart:convert';
import "package:flutter/material.dart";
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:greenwarrior/config.dart';
import 'package:http/http.dart' as http;

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
  List filteredStaffs = [];
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text;
      filteredStaffs = staffs.where((staff) {
        final name = staff['name'].toLowerCase();
        final contact = staff['contact'].toLowerCase();
        final query = searchQuery.toLowerCase();
        return name.contains(query) || contact.contains(query);
      }).toList();
    });
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
          _onSearchChanged(); // Filter the list initially
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(response.body.toString()),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(e.toString()),
        duration: const Duration(seconds: 10),
      ));
    }
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
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
        : Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text("Staff List"),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10.0),
                    ),
                  ),
                ),
              ),
            ),
            body: Visibility(
              visible: filteredStaffs.isNotEmpty,
              replacement: const Center(
                child: CircularProgressIndicator(),
              ),
              child: RefreshIndicator(
                onRefresh: getStaffList,
                child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredStaffs.length,
                    itemBuilder: (context, index) {
                      final staff = filteredStaffs[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: ClipOval(
                              child: staff['image'] != null
                                  ? Image.network(
                                      "$baseUrl${staff['image']}",
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
                          title: Text(staff['name']),
                          subtitle: Text(staff['contact']),
                        ),
                      );
                    }),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                // Navigator.pop(context);
                // Navigator.pushNamed(context, '/add_todo_page');
              },
              child: const Icon(Icons.add),
            ),
          );
  }
}
