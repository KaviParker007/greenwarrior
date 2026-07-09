

import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:greenwarrior/components/buttons.dart";
import "package:greenwarrior/components/input_fields.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;
import "package:greenwarrior/pages/login.dart";
import 'package:dropdown_search/dropdown_search.dart';

import "../../components/image_picker.dart";

class AddFuelLog extends StatefulWidget {
  const AddFuelLog({super.key});

  @override
  State<AddFuelLog> createState() => _AddFuelLogState();
}

class _AddFuelLogState extends State<AddFuelLog> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List vehicles = [];
  List fuelStations = [];
  Map vehicleAndFuelStations = {};
  TextEditingController odoReadingController = TextEditingController();
  TextEditingController fuelQuantityController = TextEditingController();
  TextEditingController fuelUnitCostController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  TextEditingController beforeImageController = TextEditingController();
  TextEditingController indentImageController = TextEditingController();

  int? vehicle;
  int? fuelStation;
  String? fuelType = "P";

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> createFuelLogMultipart(
      Map<String, dynamic> data,
      Map<String, dynamic> images,
      ) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-add-fuel-log/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)
        ..headers['authorization'] = auth;

      /// 🔹 Add normal fields
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      /// 🔹 Add images
      for (var entry in images.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          print("Adding file: ${entry.key} -> ${entry.value}");
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }

      /// 🔥 PRINT EVERYTHING BEFORE SENDING
      print("=========== REQUEST DEBUG ===========");
      print("URL: $uri");
      print("Method: ${request.method}");
      print("Headers: ${request.headers}");
      print("Fields: ${request.fields}");
      print("Files:");
      for (var file in request.files) {
        print("  Field: ${file.field}");
        print("  Filename: ${file.filename}");
        print("  Length: ${file.length}");
      }
      print("======================================");

      var streamedResponse = await request.send();

      var response = await http.Response.fromStream(streamedResponse);

      /// 🔥 PRINT RESPONSE
      print("=========== RESPONSE DEBUG ===========");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("======================================");

      return response;
    } catch (e) {
      print("ERROR: $e");
      errorMsg(e.toString());
      return http.Response("Error", 500);
    }
  }



  void addFuelLog() async {
    setState(() {
      isLoading = true;
    });

    String odoReading = odoReadingController.text;
    String fuelQuantity = fuelQuantityController.text;
    String fuelUnitCost = fuelUnitCostController.text;
    String remark = remarkController.text;

    if (vehicle == null ||
        fuelStation == null ||
        odoReading.isEmpty ||
        fuelQuantity.isEmpty ||
        fuelUnitCost.isEmpty ||
        beforeImageController.text.isEmpty) {
      errorMsg("Required * fields cannot be empty");
    } else {
      final Map<String, dynamic> data = {
        "vehicle": vehicle,
        "fuel_station": fuelStation,
        "fuel_type": fuelType,
        "odo_reading": odoReading,
        "fuel_quantity": fuelQuantity,
        "fuel_unit_cost": fuelUnitCost,
        "remark": remark,
      };

      final Map<String, dynamic> images = {
        "before_image": beforeImageController.text,   // required
        "indent_image": indentImageController.text,   // optional
      };
      print('data_____');
      print(data);
      print(images);
      var response = await createFuelLogMultipart(data, images);
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        successMsg('Fuel Log created successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/fuel_log_list');
      } else {
        errorMsg('Something went wrong');
      }
    }
    setState(() {
      isLoading = false;
    });
  }


  Future<void> getDropDownValues() async {
    setState(() {
      vehicles = [];
      odoReadingController.text = "0.0";
      fuelQuantityController.text = "1";
      fuelUnitCostController.text = "92.5";
    });
    var vehicleFuelUri = Uri.parse("$baseUrl/drf-add-fuel-log/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var fuelStationResponse = await http.get(
        vehicleFuelUri,
        headers: headers,
      );
      print('fuelStationResponse.body');
      print(fuelStationResponse.body);
      if (fuelStationResponse.statusCode == 200) {
        setState(() {
          vehicleAndFuelStations = jsonDecode(fuelStationResponse.body);
          vehicles = vehicleAndFuelStations['vehicle_list'];
          fuelStations = vehicleAndFuelStations['fuelstation_list'];
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
              "Add Fuel Log",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ================= VEHICLE & STATION =================
              sectionTitle("Vehicle & Station",
                  Icons.local_gas_station),

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
                    DropdownSearch<String>(
                      dropdownDecoratorProps:
                      DropDownDecoratorProps(dropdownSearchDecoration:
                        inputDecoration(
                            hint:
                            "Select Vehicle"),
                        baseStyle: TextStyle(
                          color: Colors.black54, // Color for the selected text
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      items: vehicles
                          .map<String>((v) =>
                          v['id'].toString())
                          .toList(),
                      itemAsString: (item) {
                        if (item == null)
                          return '';
                        return vehicles
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

                    const SizedBox(height: 14),

                    const Text(
                      "Fuel Station *",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<
                        String>(
                      style: TextStyle(
                        color: Colors.grey, // Color for the selected text
                      ),
                      decoration: inputDecoration(
                          hint: "Select Fuel Station",

                      ),

                      items: fuelStations
                          .map<
                          DropdownMenuItem<
                              String>>(
                              (value) {
                            return DropdownMenuItem<
                                String>(
                              value: value['id']
                                  .toString(),
                              child: Text(
                                value['name'].toString(),style: TextStyle(
                                color: Colors.grey, // Color for the selected text
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          fuelStation =
                              int.parse(
                                  value
                                      .toString());
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ================= FUEL DETAILS =================
              sectionTitle(
                  "Fuel Details", Icons.oil_barrel),

              styledCard(
                child: Column(
                  children: [

                    buildNumberField(
                        "Odo Reading *",
                        odoReadingController),

                    buildNumberField(
                        "Fuel Quantity *",
                        fuelQuantityController),

                    buildNumberField(
                        "Fuel Unit Cost *",
                        fuelUnitCostController),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<
                        String>(
                      value: fuelType,
                      decoration:
                      inputDecoration(
                          hint:
                          "Fuel Type"),
                      items: [
                        ['P', 'Petrol'],
                        ['D', 'Diesel'],
                        ['G', 'Gas'],
                      ]
                          .map((value) =>
                          DropdownMenuItem<
                              String>(
                            value:
                            value[0],
                            child: Text(value[1],style: TextStyle(
                              color: Colors.grey, // Color for the selected text
                            ),),
                          ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          fuelType =
                              value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ================= IMAGES =================
              sectionTitle(
                  "Upload Images",
                  Icons.camera_alt),

              buildImageCard(
                title: "Before Image *",
                controller:
                beforeImageController,
                buttonText:
                "Upload Before Image",
              ),

              buildImageCard(
                title: "Indent Image",
                controller:
                indentImageController,
                buttonText:
                "Upload Indent Image",
              ),

              // ================= REMARK =================
              sectionTitle("Remark", Icons.note),

              styledCard(
                child: TextField(
                  style: TextStyle(
                    color: Colors.black54, // Color for the selected text
                  ),
                  controller:
                  remarkController,
                  maxLines: null,
                  decoration:
                  inputDecoration(
                      hint:
                      "Enter Remark"),
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
                  "Add Fuel Log",
                  onPressed:
                  addFuelLog,
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
          style: TextStyle(
            color: Colors.black54, // Color for the selected text
          ),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: inputDecoration(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget buildImageCard({
    required String title,
    required TextEditingController controller,
    required String buttonText,
  }) {
    return styledCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54),
          ),
          const SizedBox(height: 10),
          _buildImagePreview(
              controller.text, title),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: CameraImagePicker(
              text: buttonText,
              onImagePicked: (file) {
                setState(() {
                  controller.text =
                      file.path;
                });
              },
            ),
          )
        ],
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
      fillColor: Colors.blue.shade100,
      hintStyle:  TextStyle(fontWeight:FontWeight.w500,color: Colors.grey),
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
            ),
          ),
        );
      } else {
        return _buildErrorWidget('Image file not found');
      }
    } catch (e) {
      return _buildErrorWidget('Error loading image');
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
        child: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

}
