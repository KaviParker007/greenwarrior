

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/config.dart';
import 'package:greenwarrior/pages/fuel_log/add_fuel_log.dart';
import 'package:greenwarrior/pages/fuel_log/edit_fuel_log.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class FuelLogListBuilder extends StatefulWidget {
  final List fuelLogs;
  final String username;
  final String password;
  const FuelLogListBuilder({
    super.key,
    required this.fuelLogs,
    required this.username,
    required this.password,
  });

  @override
  State<FuelLogListBuilder> createState() => _FuelLogListBuilderState();
}

class _FuelLogListBuilderState extends State<FuelLogListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void editFuelLog(Map fuelLog) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditFuelLog(
            fuelLog: fuelLog,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
      child: CircularProgressIndicator(),
    )
        : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: widget.fuelLogs.length,
      itemBuilder: (context, index) {
        final fuelLog = widget.fuelLogs[index];
        return Slidable(
          key: ValueKey(fuelLog['id']),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (context) {
                  openCameraAndUpload(fuelLog['id']);
                },
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                icon: Icons.camera_alt,
                label: 'After Image',
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔹 VEHICLE NUMBER HEADER
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fuelLog['vehicle_number'].toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Chip(
                        label: Text(
                          fuelLog['fuel_type'].toString(),
                          style: const TextStyle(
                              color: Colors.white),
                        ),
                        backgroundColor:
                        Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// 🔹 DETAILS
                  Text(
                    "Fueled By: ${fuelLog['fueled_person']}",
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Date: ${fuelLog['fuel_date']}",
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54),
                  ),

                  const SizedBox(height: 10),

                  /// 🔹 QUANTITY + COST
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_gas_station,
                              size: 18, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            "${fuelLog['fuel_quantity']} L",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.currency_rupee,
                              size: 18, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            fuelLog['fuel_unit_cost']
                                .toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        );

      },
    );
  }

  Future<void> openCameraAndUpload(int fuelLogId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image == null) return;

    await uploadAfterImage(fuelLogId, image.path);
  }

  Future<void> uploadAfterImage(int fuelLogId, String imagePath) async {
    try {
      setState(() {
        isLoading = true;
      });

      String baseUrl = AppConfig.apiUrl;
      var uri = Uri.parse("$baseUrl/drf_fuel_log_after_image/");
      var auth = 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      request.fields['id'] = fuelLogId.toString();

      request.files.add(
        await http.MultipartFile.fromPath('after_image', imagePath),
      );

      print("Uploading After Image...");
      print("URL: $uri");
      print("ID: $fuelLogId");
      print("Image Path: $imagePath");

      var response = await request.send();
      var res = await http.Response.fromStream(response);

      print("Status: ${res.statusCode}");
      print("Body: ${res.body}");

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("After Image Uploaded Successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload Failed")),
        );
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


}

class FuelLogList extends StatefulWidget {
  const FuelLogList({super.key});

  @override
  State<FuelLogList> createState() => _FuelLogListState();
}

class _FuelLogListState extends State<FuelLogList> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isSearching = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List fuelLogs = [];
  List filteredFuelLogs = [];
  TextEditingController searchController = TextEditingController();

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

  Future<void> getFuelLogs() async {
    setState(() {
      isLoading = true;
      fuelLogs = [];
      filteredFuelLogs = [];
    });
    var uri = Uri.parse("$baseUrl/drf-fuel-log-list/");

    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      print('fuellog_check');
      print(uri);
      print(username);
      print(password);
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200) {
        setState(() {
          fuelLogs = jsonDecode(response.body);
          filteredFuelLogs = List.from(fuelLogs);
        });
      } else {
        errorMsg("500 - Server Error");
      }
    } catch (e) {
      print('Exception: $e');
      errorMsg("500 - Server Error");
    }
    setState(() {
      isLoading = false;
    });
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "fuel_log");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
      await getFuelLogs();
    }
  }

  void filterFuelLogs(String query) {
    setState(() {
      filteredFuelLogs = fuelLogs.where((log) {
        final vehicleNumber = log['vehicle_number'].toString().toLowerCase();
        return vehicleNumber.contains(query.toLowerCase());
      }).toList();
    });
  }



  List<Widget> buildAppBarActions() {
    if (isSearching) {
      return [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              isSearching = false;
              searchController.clear();
              filteredFuelLogs = List.from(fuelLogs);
            });
          },
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              isSearching = true;
            });
          },
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xffF4F6FA),

        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: isSearching
              ? buildSearchField()
              : const Text(
            "Fuel Logs",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: buildAppBarActions(),
        ),

        drawer: isSearching ? null : const AppDrawer(),

        body: Visibility(
          visible: !isLoading,
          replacement: const Center(
            child: CircularProgressIndicator(),
          ),
          child: RefreshIndicator(
            onRefresh: getFuelLogs,
            child: FuelLogListBuilder(
              fuelLogs: filteredFuelLogs,
              username: username!,
              password: password!,
            ),
          ),
        ),

        floatingActionButton: isSearching
            ? null
            : FloatingActionButton.extended(
          backgroundColor:
          Theme.of(context).colorScheme.primary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                  const AddFuelLog()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("Add Fuel Log"),
        ),
      ),
    );

  }

  Widget buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search vehicle number...',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          contentPadding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: filterFuelLogs,
      ),
    );
  }

}