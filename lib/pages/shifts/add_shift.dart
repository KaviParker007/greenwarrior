import 'dart:convert';
import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/buttons.dart';
import 'package:greenwarrior/components/input_fields.dart';
import 'package:greenwarrior/components/label.dart';
import "package:greenwarrior/config.dart";
import 'package:greenwarrior/pages/login.dart';

import '../../components/image_picker.dart';

class AddShiftPage extends StatefulWidget {
  const AddShiftPage({super.key});

  @override
  State<AddShiftPage> createState() => _AddShiftPageState();
}

class _AddShiftPageState extends State<AddShiftPage> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];
  List routes = [];
  List<int> selectedRouteIds = [];
  Map<String, String> routeMapId = {};
  String? shiftName = "I";
  String? engineOilLevel = "Not Checked";
  String? coolantOilLevel = "Not Checked";
  String? outKm = "";
  int? vehicle;
  TextEditingController outKMController = TextEditingController();
  TextEditingController driverController = TextEditingController();


  String? driverType;
  String? driverId;
  TextEditingController otherDriverRemarkController = TextEditingController();
  TextEditingController driverNameController = TextEditingController();
  TextEditingController actingDriverLicenseController = TextEditingController();

  List<Map<String, dynamic>> regularDrivers = [];
  List<Map<String, dynamic>> spareDrivers = [];

  bool? audioSystem = false;
  bool? barrel = false;
  bool? rack = false;
  bool? broom = false;
  bool? annakoodai = false;
  var shiftData;
  TextEditingController frontImageController = TextEditingController();
  TextEditingController rightImageController = TextEditingController();
  TextEditingController backImageController = TextEditingController();
  TextEditingController leftImageController = TextEditingController();
  TextEditingController odoMeterImageController = TextEditingController();
  TextEditingController? vehicleComplaintController = TextEditingController();
  TextEditingController complaintDetailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  addShift(Map<String, dynamic> data, Map<String, dynamic> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-start-shift-v3/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)..headers['authorization'] = auth;

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          File imageFile = File(entry.value);
          if (await imageFile.exists()) {
            request.files.add(
              await http.MultipartFile.fromPath(entry.key, entry.value),
            );
          } else {
            print('File does not exist: ${entry.value}');
          }
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      print('Error in addShift: $e');
      return errorMsg(e.toString());
    }
  }

  void startShift() async {
    setState(() {
      isLoading = true;
    });

    if ((shiftName == null || shiftName!.isEmpty) ||
        (vehicle == null || vehicle.toString().isEmpty) ||
        (routes == [] || routes.toString().isEmpty) ||
        (driverType == null || driverType!.isEmpty) ||
        frontImageController.text.isEmpty ||
        leftImageController.text.isEmpty ||
        backImageController.text.isEmpty ||
        rightImageController.text.isEmpty ||
        odoMeterImageController.text.isEmpty) {
      errorMsg("Required * fields cannot be Empty");
    } else {
      // Prepare driver data based on driver type
      String driverName = '';
      String driverEmployeeId = '';
      String actingLicense = '';
      String otherRemark = '';

      switch (driverType) {
        case 'Regular Driver':
        case 'Spare Driver':
          driverName = regularDrivers.firstWhere(
                (driver) => driver['employee_id'].toString() == driverId,
            orElse: () => {'employee_name': ''},
          )['employee_name'];
          driverEmployeeId = driverId ?? '';
          break;
        case 'Acting Driver':
          driverName = driverNameController.text;
          actingLicense = actingDriverLicenseController.text;
          break;
        case 'Others':
          driverName = driverNameController.text;
          otherRemark = otherDriverRemarkController.text;
          break;
      }
      print('vehicle______chke');
      print(vehicle);
      print(shiftName);
      print(outKMController.text);
      print(driverType);
      print(driverEmployeeId);
      print(driverName);
      print(actingLicense);
      print(otherRemark);

      final Map<String, dynamic> data = {
        "vehicle": vehicle,
        "shift_name": shiftName,
        "out_km": outKMController.text,
        "driver_type": driverType,
        "driver_id": driverEmployeeId,
        "driver_name": driverName,
        "acting_driver_license": actingLicense,
        "other_driver_remark": otherRemark,
        "engine_oil_level": engineOilLevel,
        "coolant_oil_level": coolantOilLevel,
        "audio_system": audioSystem,
        "barrel": barrel,
        "rack": rack,
        "broom": broom,
        "annakoodai": annakoodai,
        "complaint_details": complaintDetailsController.text.isEmpty ? "-" : complaintDetailsController.text,
      };

      final Map<String, dynamic> images = {
        "start_front": frontImageController.text,
        "start_right": rightImageController.text,
        "start_back": backImageController.text,
        "start_left": leftImageController.text,
        "start_odometer": odoMeterImageController.text,
        "vehicle_complaint": vehicleComplaintController?.text ?? "",
      };

      print('data___');
      print(data);

      var response = await addShift(data, images);
      if (response.statusCode == 200) {
        successMsg('Shift created successfully');
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
      vehicles = [];
      routes = [];
      outKMController.text = "0";
    });

    var startShiftUri = Uri.parse("$baseUrl/drf-start-shift-v3/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var startShiftResponse = await http.get(startShiftUri, headers: headers);
      if (startShiftResponse.statusCode == 200) {
        shiftData = jsonDecode(startShiftResponse.body);
        setState(() {
          vehicles = shiftData['vehicles'];
          var routesList = List<Map<String, dynamic>>.from(shiftData['routes'] ?? []);
          routes = List<String>.from(routesList.map((route) => route['route']));
          routeMapId = {for (var route in routesList) route['route']: route['id'].toString()};

          // Load drivers data
          regularDrivers = List<Map<String, dynamic>>.from(shiftData['regular_drivers'] ?? []);
          spareDrivers = List<Map<String, dynamic>>.from(shiftData['spare_drivers'] ?? []);
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
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xffF4F6FA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black87),
            title: const Text("Start Shift",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),),
          ),
          body: Container(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ================= SHIFT DETAILS =================
                sectionTitle("Shift Details", Icons.access_time),

                styledCard(
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Shift Name *",style: TextStyle(fontSize: 12,color:Colors.black54,fontWeight: FontWeight.bold),),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: shiftName,
                        decoration: inputDecoration(),
                        items: ['I', 'II', 'III', 'Others']
                            .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value,style: TextStyle(fontSize: 12,color:Colors.grey,fontWeight: FontWeight.bold)),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            shiftName = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // ================= VEHICLE =================
                sectionTitle("Vehicle Information", Icons.directions_bus),

                styledCard(
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Vehicle *",style: TextStyle(fontSize: 12,color:Colors.black54,fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      DropdownSearch<String>(

                        dropdownDecoratorProps: DropDownDecoratorProps(

                          dropdownSearchDecoration: inputDecoration(
                            hint: "Select Vehicle",

                          ),
                          baseStyle: TextStyle(
                            color: Colors.black54, // Color for the selected text
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        items: vehicles
                            .map<String>((v) => v['id'].toString())
                            .toList(),
                        itemAsString: (item) {
                          if (item == null) return '';
                          return vehicles
                              .firstWhere(
                                  (v) => v['id'].toString() == item,
                              orElse: () => {'vehicle_number': ''})['vehicle_number']
                              .toString();
                        },
                        onChanged: (value) {
                          if (value != null) {
                            var selectedVehicle = vehicles.firstWhere(
                                    (v) => v['id'].toString() == value);
                            setState(() {
                              vehicle = int.parse(value);
                              double currentKm = selectedVehicle['current_km'].toDouble();
                              outKMController.text = currentKm.toStringAsFixed(0);
                            });
                          }
                        },
                        selectedItem: vehicle?.toString(),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Out KM",style: TextStyle(fontSize: 12,color:Colors.black54,fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      NumberField(
                        controller: outKMController,
                        padding: 12,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                        ],
                      ),
                    ],
                  ),
                ),

                // ================= DRIVER =================
                sectionTitle("Driver Information", Icons.person),

                styledCard(
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Driver Type *",style: TextStyle(fontSize: 12,color:Colors.black54,fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: driverType,
                        decoration: inputDecoration(),
                        items: ['Regular', 'Spare', 'Acting', 'Others']
                            .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value,style: TextStyle(fontSize: 12,color:Colors.grey,fontWeight: FontWeight.bold)),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            driverType = value;
                            driverId = null;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // Conditional driver UI remains same
                      if (driverType == 'Acting')
                        Column(
                          children: [
                            TextField(
                              controller: driverNameController,
                              decoration:
                              inputDecoration(hint: "Driver Name"),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller:
                              actingDriverLicenseController,
                              decoration:
                              inputDecoration(hint: "License No"),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // ================= CHECKLIST =================
                sectionTitle("Vehicle Checklist", Icons.check_circle),

                styledCard(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      buildCheckTile("Audio", audioSystem, (val) {
                        setState(() => audioSystem = val);
                      }),
                      buildCheckTile("Barrel", barrel, (val) {
                        setState(() => barrel = val);
                      }),
                      buildCheckTile("Rack", rack, (val) {
                        setState(() => rack = val);
                      }),
                      buildCheckTile("Broom", broom, (val) {
                        setState(() => broom = val);
                      }),
                      buildCheckTile("Annakoodai", annakoodai, (val) {
                        setState(() => annakoodai = val);
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ================= SUBMIT BUTTON =================
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    :  SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: "Start Shift",
                    onPressed: startShift,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),

        ),
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
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54
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
      fillColor: Colors.blue.shade100,
      hintStyle: TextStyle(
        color: Colors.blue
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
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

  Widget buildCheckTile(
      String title, bool? value, Function(bool?) onChanged) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
          ),
          Text(title,style: TextStyle(fontSize: 12,color:Colors.black54,fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


  Widget _buildImagePreview(String imagePath, String placeholderText) {
    if (imagePath.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$placeholderText Not Uploaded',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    try {
      File imageFile = File(imagePath);
      if (imageFile.existsSync()) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              imageFile,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return _buildErrorWidget('Failed to load image');
              },

            ),
          ),
        );
      } else {
        return _buildErrorWidget('Image file not found');
      }
    } catch (e) {
      return _buildErrorWidget('Error loading image: $e');
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
