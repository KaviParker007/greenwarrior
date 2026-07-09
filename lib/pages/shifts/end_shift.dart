import 'dart:convert';
import 'dart:io';
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

class EndShiftPage extends StatefulWidget {
  final int shiftId;
  const EndShiftPage({super.key, required this.shiftId});

  @override
  State<EndShiftPage> createState() => _EndShiftPageState();
}

class _EndShiftPageState extends State<EndShiftPage> {
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
  TextEditingController shiftRemarkController = TextEditingController();
  TextEditingController inKmController = TextEditingController();
  TextEditingController imageController = TextEditingController();
  TextEditingController odoMeterImageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  endShift(Map<String, dynamic> data, Map<String, String> images) async {
    try {
      var uri = Uri.parse("$baseUrl/drf-end-shift-v2/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      var request = http.MultipartRequest('POST', uri)..headers['authorization'] = auth;

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return response;
    } catch (e) {
      return errorMsg(e.toString());
    }
  }

  void startShift() async {
    setState(() {
      isLoading = true;
    });

    if (binCountController.text.isEmpty ||
        wetWasteController.text.isEmpty ||
        recycleWasteController.text.isEmpty ||
        dryWasteController.text.isEmpty ||
        inertsController.text.isEmpty ||
        houseHoldHazardController.text.isEmpty ||
        greenGarbageController.text.isEmpty ||
        otherWasteController.text.isEmpty ||
        (destinationId == null || destinationId.toString().isEmpty) ||
        inKmController.text.isEmpty ||
        imageController.text.isEmpty ||
        odoMeterImageController.text.isEmpty) {
      errorMsg("Required * fields cannot be Empty");
    } else {
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
        "shift_remark": shiftRemarkController.text,
        "in_km": int.parse(inKmController.text),
      };

      final Map<String, String> images = {
        "end_image": imageController.text,
        "end_odometer": odoMeterImageController.text,
      };

      var response = await endShift(data, images);
      if (response.statusCode == 200) {
        successMsg('shift end successfully');
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
              "End Shift",
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
                  "Waste Collection Details", Icons.delete),

              styledCard(
                child: Column(
                  children: [

                    buildNumberField(
                        "Bin Count *", binCountController),
                    buildNumberField(
                        "Wet Waste *", wetWasteController),
                    buildNumberField("Recyclable Waste *",
                        recycleWasteController),
                    buildNumberField(
                        "Dry Waste *", dryWasteController),
                    buildNumberField(
                        "Inerts *", inertsController),
                    buildNumberField("Household Hazard *",
                        houseHoldHazardController),
                    buildNumberField("Green Garbage *",
                        greenGarbageController),
                    buildNumberField(
                        "Other Waste *", otherWasteController),
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

                          hint: "Select Destination",
                      ),

                      items: destination
                          .map<DropdownMenuItem<String>>(
                              (dynamic value) {
                            return DropdownMenuItem<String>(
                              value:
                              value['id'].toString(),
                              child: Text(
                                value['name'].toString(),
                                style: TextStyle(
                                    color: Colors.grey
                                ),
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

              // ================= KM & REMARK =================
              sectionTitle(
                  "Shift Summary", Icons.note_alt),

              styledCard(
                child: Column(
                  children: [

                    buildNumberField("IN KM *", inKmController),

                    TextField(
                      controller:
                      tripRemarkController,
                      maxLines: null,
                      style: TextStyle(
                        color: Colors.black54
                      ),
                      decoration: inputDecoration(hint: "Trip Remark",),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller:
                      shiftRemarkController,
                      maxLines: null,
                      style: TextStyle(
                          color: Colors.black54
                      ),
                      decoration:
                      inputDecoration(
                          hint:
                          "Shift Remark"),
                    ),
                  ],
                ),
              ),

              // ================= IMAGES =================
              sectionTitle(
                  "Upload Images", Icons.camera_alt),

              buildImageCard(
                title: "End Image *",
                controller: imageController,
                buttonText: "Upload End Image",
              ),

              buildImageCard(
                title: "End Odo-meter Image *",
                controller:
                odoMeterImageController,
                buttonText:
                "Upload Odo-meter Image",
              ),

              const SizedBox(height: 20),

              isLoading
                  ? const Center(
                  child:
                  CircularProgressIndicator())
                  : SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: "End Shift",
                  onPressed: startShift,
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  Widget buildNumberField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9]')),
          ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildImagePreview(
              controller.text, title),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: CameraImagePicker(
              onImagePicked: (value) {
                setState(() {
                  controller.text = value.path;
                });
              },
              text: buttonText,
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
      fillColor: Colors.grey.shade100,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      hintStyle: TextStyle(
        color: Colors.grey,
      ),
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
