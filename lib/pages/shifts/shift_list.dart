import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/config.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:greenwarrior/pages/shifts/add_shift.dart';
import 'package:greenwarrior/pages/shifts/rotate_shift.dart';

import 'end_shift.dart';

class ShiftListBuilder extends StatefulWidget {
  final List shifts;
  const ShiftListBuilder({super.key, required this.shifts});

  @override
  State<ShiftListBuilder> createState() => _ShiftListBuilderState();
}

class _ShiftListBuilderState extends State<ShiftListBuilder> with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.shifts.length,
            itemBuilder: (context, index) {
              final shift = widget.shifts[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    if (shift['end_time'] == null) ...[
                      // EDIT BUTTON
                      SlidableAction(
                        onPressed: (_) => controller.close(),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.edit,
                        label: 'Edit',
                      ),

                      // ROTATE TRIP BUTTON
                      SlidableAction(
                        onPressed: (_) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RotateShiftPage(shiftId: shift['id'])),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.repeat,
                        label: 'Rotate',
                      ),

                      // END TRIP BUTTON
                      SlidableAction(
                        onPressed: (_) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EndShiftPage(shiftId: shift['id'])),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        icon: Icons.timer_off,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        label: 'End',
                        // spacing: 8,
                      )
                    ],
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [

                          /// STATUS STRIP
                          Container(
                            width: 6,
                            height: 70,
                            decoration: BoxDecoration(
                              color: shift['end_time'] == null
                                  ? Colors.green
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          const SizedBox(width: 15),

                          /// SHIFT DETAILS
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                /// VEHICLE NUMBER
                                Text(
                                  shift['vehicle_number'].toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: shift['end_time'] == null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                /// SHIFT NAME
                                Text(
                                  shift['shift_name'].toString(),
                                  style: TextStyle(
                                    color: shift['end_time'] == null
                                        ? Colors.black54
                                        : Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                /// DRIVER + STATUS
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Driver: ${shift['driver']}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: shift['end_time'] == null
                                            ? Colors.black54
                                            : Colors.grey,
                                      ),
                                    ),

                                    _shiftStatusBadge(shift),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              );
            },
          );
  }

  Widget _shiftStatusBadge(Map shift) {
    bool isActive = shift['end_time'] == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? "ACTIVE" : "ENDED",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

}

class ShiftListPage extends StatefulWidget {
  const ShiftListPage({super.key});

  @override
  State<ShiftListPage> createState() => _ShiftListPageState();
}

class _ShiftListPageState extends State<ShiftListPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List todayShift = [];
  List shifts = [];
  List unclosedShift = [];
  String title = "Todays Shifts";

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  void errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> getTodayShift({
    String filter = "is_active",
    bool value = true,
  }) async {
    setState(() {
      isLoading = true;
      todayShift = [];
      unclosedShift = [];
    });
    var uri = Uri.parse("$baseUrl/drf-today-shift-list-v2/");

    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      print('shift_check');
      print(uri);
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200) {
        setState(() {
          var responseData = jsonDecode(response.body);
          todayShift = responseData['today_shift_list'];
          unclosedShift = responseData['unclosed_shift'];
          shifts = todayShift;
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
        errorMsg("500 - Server Error");
      }
    } catch (e) {
      // print('Exception: $e');
      errorMsg("500 - Server Error");
    }
    setState(() {
      isLoading = false;
    });
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "shifts");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getTodayShift();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : Scaffold(
      backgroundColor: const Color(0xffF4F6FA),

      /// MODERN APP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CustomSearchDelegate(shifts: shifts),
              );
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (String filter) {
              if (filter == "today") {
                setState(() {
                  shifts = todayShift;
                  title = "Today's Shifts";
                });
              } else if (filter == "unclosed") {
                setState(() {
                  shifts = unclosedShift;
                  title = "Unclosed Shifts";
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: "today",
                child: Text("Today's Shifts"),
              ),
              PopupMenuItem(
                value: "unclosed",
                child: Text("Unclosed Shifts"),
              ),
            ],
          ),
        ],
      ),

      drawer: const AppDrawer(),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: getTodayShift,
        child: ShiftListBuilder(shifts: shifts),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add),
        label: const Text("Add Shift"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddShiftPage()),
          );
        },
      ),
    );
  }

}

class CustomSearchDelegate extends SearchDelegate {
  List shifts = [];
  CustomSearchDelegate({required this.shifts});
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
      return ShiftListBuilder(shifts: shifts);
    } else {
      for (var shift in shifts) {
        for (var searchKey in ['vehicle_number', 'driver']) {
          if (shift[searchKey]
              .toString()
              .toLowerCase()
              .contains(searchQuery)) {
            if (!uniqueIds.contains(shift['id'])) {
              searchList.add(shift);
              uniqueIds.add(shift['id']);
            }
          }
        }
      }
      return ShiftListBuilder(shifts: searchList);
    }
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ShiftListBuilder(shifts: shifts);
  }
}