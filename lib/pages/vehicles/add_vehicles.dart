import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/buttons.dart';
import 'package:greenwarrior/components/input_fields.dart';
import 'package:greenwarrior/components/label.dart';
import "package:greenwarrior/config.dart";
import 'package:greenwarrior/pages/login.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class VehicleType {
  final String value;
  final String lable;

  VehicleType(this.value, this.lable);
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  TextEditingController vehicleNumberController = TextEditingController();
  TextEditingController currentKMController = TextEditingController();
  TextEditingController loadEstimationController = TextEditingController();
  String? vehicleType;
  String? possession;
  bool? isActive = true;
  bool? isSpare = false;
  bool? isUnderMaintenance = false;
  TextEditingController remarkController = TextEditingController();
  int? supervisor;
  int? zone;
  int? workshop;
  List staffs = [];
  List zones = [];
  List workshops = [];

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

  Future<http.Response> createVehicle(String body) async {
    var uri = Uri.parse("$baseUrl/drf-add-vehicle/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addVehicle() async {
    setState(() {
      isLoading = true;
    });
    String? vehicleNumber = vehicleNumberController.text;
    String? currentKM = currentKMController.text;
    String? loadEstimation = loadEstimationController.text;

    var body = {
      "vehicle_number": vehicleNumber.toString(),
      "vehicle_type": vehicleType.toString(),
      "possession": possession.toString(),
      "current_km": double.parse(currentKM),
      "is_active": isActive,
      "is_spare": isSpare,
      "is_under_maintenance": isUnderMaintenance,
      "load_estimation": double.parse(loadEstimation),
      "remark": remarkController.text.toString(),
      "zone": zone,
      "workshop": workshop,
      "supervisor": []
    };

    if (supervisor != null) {
      (body['supervisor'] as List).add(supervisor);
    }

    if (vehicleNumber.isEmpty ||
        currentKM.isEmpty ||
        loadEstimation.isEmpty ||
        vehicleType!.isEmpty ||
        possession!.isEmpty) {
      errorMsg("Required * fields cannot be null");
    } else {
      var response = await createVehicle(jsonEncode(body));
      if (response.statusCode == 201) {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/vehicles_list');
      } else {
        print(response.body);
        errorMsg("Unable to create Vehicle");
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getDropDownValues() async {
    setState(() {
      staffs = [];
      zones = [];
      workshops = [];
    });
    var staffUri = Uri.parse("$baseUrl/drf-staff-list/");
    var zoneUri = Uri.parse("$baseUrl/test/zone/");
    var workshopUri = Uri.parse("$baseUrl/test/workshop/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    // STAFFS
    try {
      var staffResponse = await http.post(
        staffUri,
        headers: headers,
        body: jsonEncode({'filter': 'active'}),
      );
      if (staffResponse.statusCode == 200) {
        setState(() {
          staffs = jsonDecode(staffResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }

    // ZONES
    try {
      var zoneResponse = await http.get(zoneUri, headers: headers);
      if (zoneResponse.statusCode == 200) {
        setState(() {
          zones = jsonDecode(zoneResponse.body);
        });
      }
    } catch (e) {
      print('Exception: $e');
    }

    // WORKSHOP
    try {
      var workshopResponse = await http.get(workshopUri, headers: headers);
      if (workshopResponse.statusCode == 200) {
        setState(() {
          workshops = jsonDecode(workshopResponse.body);
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
    await getDropDownValues();
    setState(() {
      isStarting = false;
    });
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
              "Add Vehicle",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  /// VEHICLE NUMBER
                  const LabelText(text: "Vehicle Number*"),
                  const SizedBox(height: 6),
                  BasicInputField(
                    controller:
                    vehicleNumberController,
                    padding: 12,
                  ),
                  const SizedBox(height: 18),

                  /// VEHICLE TYPE
                  const LabelText(text: "Vehicle Type*"),
                  const SizedBox(height: 6),
                  _styledDropdown(
                    items: [
                      ['Push Cart', 'Push Cart'],
                      ['Tricycle', 'Tricycle'],
                      ['BOV',
                        'Battery Operated Vehicle (BOV)'],
                      ['LCV',
                        'Light Commercial Vehicle (LCV)'],
                      ['HCV',
                        'High Commercial Vehicle (HCV)'],
                      ['Compactor', 'Compactor'],
                      ['Hook Loader', 'Hook Loader'],
                      ['Dumper Placer',
                        'Dumper Placer'],
                      ['Tipper', 'Tipper'],
                      ['SSSM',
                        'Small Street Sweeping Machine'],
                      ['LSSM',
                        'Large Street Sweeping Machine'],
                      ['EMV',
                        'Earth Moving Vehicle'],
                      ['Tractor', 'Tractor'],
                      ['Others', 'Others'],
                    ],
                    onChanged: (value) {
                      setState(() {
                        vehicleType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  /// POSSESSION
                  const LabelText(text: "Possession*"),
                  const SizedBox(height: 6),
                  _styledDropdown(
                    items: [
                      ['OL', 'OURLAND'],
                      ['GOVT', 'GOVERNMENT'],
                      ['RENT', 'PRIVATE'],
                    ],
                    onChanged: (value) {
                      setState(() {
                        possession = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  /// CURRENT KM
                  const LabelText(text: "Current KM*"),
                  const SizedBox(height: 6),
                  NumberField(
                    controller: currentKMController,
                    padding: 12,
                  ),
                  const SizedBox(height: 18),

                  /// STATUS CHECKBOX SECTION
                  _buildCheckboxSection(),

                  const SizedBox(height: 18),

                  /// LOAD ESTIMATION
                  const LabelText(
                      text: "Load estimation*"),
                  const SizedBox(height: 6),
                  NumberField(
                    controller:
                    loadEstimationController,
                    padding: 12,
                  ),
                  const SizedBox(height: 18),

                  /// REMARK
                  const LabelText(text: "Remark"),
                  const SizedBox(height: 6),
                  TextAreaField(
                    controller: remarkController,
                    padding: 12,
                  ),
                  const SizedBox(height: 25),

                  /// SUBMIT BUTTON
                  isLoading
                      ? const Center(
                      child:
                      CircularProgressIndicator())
                      : SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: "Submit Vehicle",
                      onPressed: addVehicle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _styledDropdown({
    required List<List<String>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 26,
        color: Colors.grey,
      ),
      items: items.map((value) {
        return DropdownMenuItem<String>(

          value: value[0],
          child: Text(
            value[1],
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        );
      }).toList(),
      decoration: InputDecoration(

        filled: true,
        fillColor: const Color(0xffF7F9FC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onChanged: onChanged,
    );
  }
  Widget _buildCheckboxSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xffF7F9FC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _checkboxTile("Is Active", isActive, (val) {
            setState(() => isActive = val);
          }),
          _checkboxTile("Is Spare", isSpare, (val) {
            setState(() => isSpare = val);
          }),
          _checkboxTile(
              "Is Under Maintenance",
              isUnderMaintenance, (val) {
            setState(() => isUnderMaintenance = val);
          }),
        ],
      ),
    );
  }
  Widget _checkboxTile(
      String title, bool? value, Function(bool?) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor:
          Theme.of(context).colorScheme.primary,
          onChanged: onChanged,
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

}
