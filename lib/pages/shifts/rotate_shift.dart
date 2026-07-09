import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/buttons.dart';
import 'package:greenwarrior/components/input_fields.dart';
import 'package:greenwarrior/components/label.dart';
import "package:greenwarrior/config.dart";
import 'package:greenwarrior/pages/login.dart';

class RotateShiftPage extends StatefulWidget {
  final int shiftId;
  const RotateShiftPage({super.key, required this.shiftId});

  @override
  State<RotateShiftPage> createState() => _RotateShiftPageState();
}

class _RotateShiftPageState extends State<RotateShiftPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List destination = [];
  int? destinationId;
  List<int> selectedRouteIds = [];
  TextEditingController binCountController = TextEditingController();
  TextEditingController wetWasteController = TextEditingController();
  TextEditingController recycleWasteController = TextEditingController();
  TextEditingController dryWasteController = TextEditingController();
  TextEditingController inertsController = TextEditingController();
  TextEditingController houseHoldHazardController = TextEditingController();
  TextEditingController greenGarbageController = TextEditingController();
  TextEditingController otherWasteController = TextEditingController();
  TextEditingController tripRemarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  rotateShift(Map<String, dynamic> data) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-rotate-trip-v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'authorization': auth},
        body: jsonEncode(data),
      );
      return response;
    } catch (e) {
      return errorMsg(e.toString());
    }
  }

  void swapShift() async {
    setState(() {
      isLoading = true;
    });

    final Map<String, dynamic> data = {
      "shift_id": widget.shiftId,
      "bin_count": int.parse(binCountController.text),
      "wet_waste": int.parse(wetWasteController.text),
      "recyclable_waste": int.parse(recycleWasteController.text),
      "dry_waste": int.parse(dryWasteController.text),
      "inerts": int.parse(inertsController.text),
      "household_hazard": int.parse(houseHoldHazardController.text),
      "green_garbages": int.parse(greenGarbageController.text),
      "other_waste": int.parse(otherWasteController.text),
      "destination": destinationId,
      "trip_remark": tripRemarkController.text,
    };

    if (binCountController.text.isEmpty ||
        wetWasteController.text.isEmpty ||
        recycleWasteController.text.isEmpty ||
        dryWasteController.text.isEmpty ||
        inertsController.text.isEmpty ||
        houseHoldHazardController.text.isEmpty ||
        greenGarbageController.text.isEmpty ||
        otherWasteController.text.isEmpty ||
        (destinationId == null || destinationId.toString().isEmpty)) {
      errorMsg("Required * fields cannot be Empty");
    } else {
     var response = await rotateShift(data);
      if (response.statusCode == 200) {
        successMsg('shift swap successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/shift_list');
      } else {
        print(response.body);
        errorMsg(response.body);
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getDropDownValues() async {
    setState(() {
      destination = [];
      binCountController.text = '0';
      wetWasteController.text = '0';
      recycleWasteController.text = '0';
      dryWasteController.text = '0';
      inertsController.text = '0';
      houseHoldHazardController.text = '0';
      greenGarbageController.text = '0';
      otherWasteController.text = '0';
    });
    var destinationUri = Uri.parse("$baseUrl/drf-destination-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var destinationResponse = await http.get(
        destinationUri,
        headers: headers,
      );
      if (destinationResponse.statusCode == 200) {
        var shiftData = jsonDecode(destinationResponse.body);
        setState(() {
          destination = shiftData;
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
    await getDropDownValues();
    setState(() {
      isStarting = false;
    });
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

  void successMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(msg),
        duration: const Duration(seconds: 3),
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
              "Rotate Shift",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ================= WASTE DETAILS =================
              sectionTitle(
                  "Trip Waste Details", Icons.swap_horiz),

              styledCard(
                child: Column(
                  children: [
                    buildNumberField(
                        "Bin Count *", binCountController),
                    buildNumberField(
                        "Wet Waste *", wetWasteController),
                    buildNumberField(
                        "Recyclable Waste *",
                        recycleWasteController),
                    buildNumberField(
                        "Dry Waste *", dryWasteController),
                    buildNumberField(
                        "Inerts *", inertsController),
                    buildNumberField(
                        "Household Hazard *",
                        houseHoldHazardController),
                    buildNumberField(
                        "Green Garbage *",
                        greenGarbageController),
                    buildNumberField(
                        "Other Waste *",
                        otherWasteController),
                  ],
                ),
              ),

              // ================= DESTINATION =================
              sectionTitle(
                  "Destination Details", Icons.location_on),

              styledCard(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Destination *",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      decoration: inputDecoration(
                          hint: "Select Destination"),
                      items: destination
                          .map<DropdownMenuItem<String>>(
                              (dynamic value) {
                            return DropdownMenuItem<String>(
                              value:
                              value['id'].toString(),
                              child: Text(
                                value['name']
                                    .toString(),
                                style: const TextStyle(
                                    color:
                                    Colors.black54),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          destinationId =
                              int.parse(
                                  value.toString());
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ================= TRIP REMARK =================
              sectionTitle(
                  "Trip Remark", Icons.note_alt),

              styledCard(
                child: TextField(
                  controller:
                  tripRemarkController,
                  maxLines: null,
                  style: const TextStyle(
                      color: Colors.black54),
                  decoration: inputDecoration(
                      hint:
                      "Enter Trip Remark"),
                ),
              ),

              const SizedBox(height: 20),

              isLoading
                  ? const Center(
                  child:
                  CircularProgressIndicator())
                  : SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: "Rotate Shift",
                  onPressed: swapShift,
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  Widget buildNumberField(
      String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp('[0-9]')),
          ],
          decoration: inputDecoration(),
        ),
        const SizedBox(height: 14),
      ],
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
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      hintStyle: const TextStyle(color: Colors.grey),
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

}
