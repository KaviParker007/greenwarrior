import "dart:convert";
import "dart:io";
import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;
import "package:greenwarrior/pages/login.dart";
import "package:greenwarrior/pages/vehicles/edit_vehicle.dart";

import "../../components/buttons.dart";
import "../../components/image_picker.dart";

class VehicleView extends StatefulWidget {
  final int vehicleId;
  const VehicleView({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleView> createState() => _VehicleViewState();
}

class _VehicleViewState extends State<VehicleView> {
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  Map vehicle = {};
  bool isLoggedIn = false;
  String? username;
  String? password;
  String frontImage = '';
  String leftImage = '';
  String backImage = '';
  String rightImage = '';

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

  void getVehicle(int id) async {
    setState(() {
      isStarting = true;
    });
    var uri = Uri.parse("$baseUrl/drf-vehicle-detail/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var body = jsonEncode({"vehicle_id": id});
    var response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Response Body:');
      print(response.body);
      setState(() {
        vehicle = jsonDecode(response.body);
      });
    } else {
      errorMsg("Unable to find Vehicle");
      Navigator.pop(context);
      Navigator.pushNamed(context, "/vehicles_list");
    }

    setState(() {
      isStarting = false;
    });
  }

  _uploadImage() async {
    setState(() {
      isLoading = true;
    });
    try {
      var uri = Uri.parse("$baseUrl/drf-upload-photoes/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = auth;
      final vehicleIdBytes = utf8.encode(vehicle['id'].toString());
      request.fields['vehicle_id'] = String.fromCharCodes(vehicleIdBytes);

      Future<void> addFileIfExists(String filePath, String fieldName) async {
        if (filePath.isNotEmpty && File(filePath).existsSync()) {
          request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
        } else {
          print('$fieldName image path is invalid or empty: $filePath');
        }
      }

      await addFileIfExists(frontImage, 'front');
      await addFileIfExists(backImage, 'back');
      await addFileIfExists(leftImage, 'left');
      await addFileIfExists(rightImage, 'right');

      final response = await request.send();
      print(response.reasonPhrase);
      if (response.statusCode == 200) {
        successMsg('Image\'s Uploaded Successfully');
      } else {
        errorMsg('Image\'s Uploaded Failed');
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      return errorMsg(e.toString());
    }
  }

  void checkLoginStatus() async {
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
    getVehicle(widget.vehicleId);
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : isStarting
        ? const Scaffold(
        body: Center(child: CircularProgressIndicator()))
        : Scaffold(
      backgroundColor: const Color(0xffF4F6FA),

      /// MODERN APP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme:
        const IconThemeData(color: Colors.black87),
        title: Text(
          vehicle['vehicle_number'].toString(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditVehicle(vehicleId: vehicle['id']),
                ),
              );
            },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// HEADER CARD
            _vehicleHeaderCard(),

            const SizedBox(height: 20),

            /// VEHICLE DETAILS CARD
            _vehicleDetailsCard(),

            const SizedBox(height: 20),

            /// IMAGE SECTIONS
            _imageSection(
                title: "Vehicle Front Image",
                imageUrl: vehicle['vehicle_front_photo'],
                localPath: frontImage,
                onPick: (value) {
                  setState(() {
                    frontImage = value.path;
                  });
                }),

            _imageSection(
                title: "Vehicle Left Image",
                imageUrl: vehicle['vehicle_left_photo'],
                localPath: leftImage,
                onPick: (value) {
                  setState(() {
                    leftImage = value.path;
                  });
                }),

            _imageSection(
                title: "Vehicle Back Image",
                imageUrl: vehicle['vehicle_back_photo'],
                localPath: backImage,
                onPick: (value) {
                  setState(() {
                    backImage = value.path;
                  });
                }),

            _imageSection(
                title: "Vehicle Right Image",
                imageUrl: vehicle['vehicle_right_photo'],
                localPath: rightImage,
                onPick: (value) {
                  setState(() {
                    rightImage = value.path;
                  });
                }),

            const SizedBox(height: 25),

            /// UPLOAD BUTTON
            isLoading
                ? const Center(
                child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: "Upload Images",
                onPressed: _uploadImage,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _vehicleHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xff4e73df), Color(0xff224abe)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicle['vehicle_number'].toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vehicle['vehicle_type'].toString(),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
  Widget _vehicleDetailsCard() {
    return Container(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _infoRow("Possession",
                vehicle["possession"].toString()),
            _infoRow("Current KM",
                vehicle["current_km"].toString()),
            _infoRow(
                "Zone", vehicle["zone_code"].toString()),
            _infoRow(
                "Workshop", vehicle["workshop"].toString()),
            if (vehicle['remark']
                .toString()
                .isNotEmpty)
              _infoRow(
                  "Remark", vehicle["remark"].toString()),
          ],
        ),
      ),
    );
  }
  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 15, color: Colors.black54,fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  Widget _imageSection({
    required String title,
    required String? imageUrl,
    required String localPath,
    required Function(dynamic) onPick,
  }) {
    return Container(
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
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54
              )
            ),
            const SizedBox(height: 10),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(12),
              child: imageUrl != null
                  ? CachedNetworkImage(
                height: 180,
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                Center(
                  child: const Icon(
                    Icons.error,
                    size: 25,
                    color: Colors.grey,
                  ),
                ),
              )
                  : (localPath.isNotEmpty)
                  ? Image.file(
                File(localPath),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              )
                  : Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Text("Image Not Yet Uploaded",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: CameraImagePicker(
                onImagePicked: onPick,
                text: "Upload",
              ),
            )
          ],
        ),
      ),
    );
  }

}
