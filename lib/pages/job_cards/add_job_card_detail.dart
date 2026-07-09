import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:greenwarrior/components/buttons.dart";
import "package:greenwarrior/components/input_fields.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;
import "package:greenwarrior/pages/login.dart";
import 'package:dropdown_search/dropdown_search.dart';

class AddJobCardDetail extends StatefulWidget {
  const AddJobCardDetail({super.key});

  @override
  State<AddJobCardDetail> createState() => _AddJobCardDetailState();
}

class _AddJobCardDetailState extends State<AddJobCardDetail> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  Map vehicleAndWorkshop = {};
  List vehiclesList = [];
  List workShopsList = [];
  TextEditingController workController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  int? vehicle;
  int? workShop;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> createJobCard(String body) async {
    var uri = Uri.parse("$baseUrl/drf-add-job-card/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addJobCard() async {
    setState(() {
      isLoading = true;
    });
    String? work = workController.text;
    String? remark = remarkController.text;

    if (vehicle == null ||
        workShop == null || work.isEmpty) {
      errorMsg("Required * fields cannot be null");
    } else {
      var body = {
        "vehicle": int.parse(vehicle.toString()),
        "workshop": int.parse(workShop.toString()),
        "work": work,
        "work_assignee_remark": remark
      };

      var response = await createJobCard(jsonEncode(body));
      if (response.statusCode == 200) {
        successMsg('job card created successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/job_card_list');
      } else {
        print(response.body);
        errorMsg("Unable to create Job Card");
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getDropDownValues() async {
    setState(() {
      vehiclesList = [];
      workShopsList = [];
    });
    var vehicleWorkshopUri = Uri.parse("$baseUrl/drf-add-job-card/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var vehicleWorkshopResponse = await http.get(
        vehicleWorkshopUri,
        headers: headers,
      );
      if (vehicleWorkshopResponse.statusCode == 200) {
        setState(() {
          vehicleAndWorkshop = jsonDecode(vehicleWorkshopResponse.body);
          vehiclesList = vehicleAndWorkshop['vehicles'];
          workShopsList = vehicleAndWorkshop['workshops'];
        });
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  void checkLoginStatus() async {
    setState(() {
      isStarting = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "job_card");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getDropDownValues();
    setState(() {
      isStarting = false;
    });
  }

  void successMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ),
    );
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

  Widget sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget styledCard({required Widget child}) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : isStarting
        ? const Center(child: CircularProgressIndicator())
        : GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xffF4F6FA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            iconTheme:
            const IconThemeData(color: Colors.black87),
            title: const Text(
              "Add Job Card",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ================= VEHICLE & WORKSHOP =================
              sectionTitle(
                  "Assignment Details",
                  Icons.build_circle),

              styledCard(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Vehicle *",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54),
                    ),
                    const SizedBox(height: 6),

                    /// VEHICLE DROPDOWN
                    DropdownSearch<String>(
                      dropdownDecoratorProps:
                      DropDownDecoratorProps(
                        dropdownSearchDecoration:
                        inputDecoration(
                            hint:
                            "Select Vehicle"),
                        baseStyle: const TextStyle(
                            color: Colors.black54),
                      ),
                      popupProps:
                      const PopupProps.menu(
                          showSearchBox:
                          true),
                      items: vehiclesList
                          .map<String>((v) =>
                          v['id']
                              .toString())
                          .toList(),
                      itemAsString: (item) {
                        if (item == null)
                          return '';
                        return vehiclesList
                            .firstWhere(
                              (v) =>
                          v['id']
                              .toString() ==
                              item,
                          orElse: () => {
                            'vehicle_number':
                            ''
                          },
                        )['vehicle_number']
                            .toString();
                      },
                      onChanged: (value) {
                        setState(() {
                          vehicle = int.parse(
                              value.toString());
                        });
                      },
                      selectedItem:
                      vehicle?.toString(),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Workshop *",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54),
                    ),
                    const SizedBox(height: 6),

                    /// WORKSHOP DROPDOWN
                    DropdownSearch<String>(
                      dropdownDecoratorProps:
                      DropDownDecoratorProps(
                        dropdownSearchDecoration:
                        inputDecoration(
                            hint:
                            "Select Workshop"),
                        baseStyle: const TextStyle(
                            color: Colors.black54),
                      ),
                      popupProps:
                      const PopupProps.menu(
                          showSearchBox:
                          true),
                      items: workShopsList
                          .map<String>((v) =>
                          v['id']
                              .toString())
                          .toList(),
                      itemAsString: (item) {
                        if (item == null)
                          return '';
                        return workShopsList
                            .firstWhere(
                              (v) =>
                          v['id']
                              .toString() ==
                              item,
                          orElse: () => {
                            'workshop_name':
                            ''
                          },
                        )['workshop_name']
                            .toString();
                      },
                      onChanged: (value) {
                        setState(() {
                          workShop =
                              int.parse(value
                                  .toString());
                        });
                      },
                      selectedItem:
                      workShop?.toString(),
                    ),
                  ],
                ),
              ),

              // ================= WORK DETAILS =================
              sectionTitle(
                  "Work Details",
                  Icons.description),

              styledCard(
                child: Column(
                  children: [

                    TextField(
                      controller:
                      workController,
                      style: TextStyle(
                          color: Colors.black54
                      ),
                      decoration:
                      inputDecoration(
                          hint:
                          "Work Description *"),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                      remarkController,
                      maxLines: null,
                      style: TextStyle(
                        color: Colors.black54
                      ),

                      decoration:
                      inputDecoration(
                          hint:
                          "Work Assignee Remark"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              isLoading
                  ? const Center(
                  child:
                  CircularProgressIndicator())
                  : SizedBox(
                width:
                double.infinity,
                child: PrimaryButton(
                  text:
                  "Create Job Card",
                  onPressed:
                  addJobCard,
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

}
