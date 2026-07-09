import "dart:convert";
import "package:flutter/material.dart";
import "package:greenwarrior/components/buttons.dart";
import "package:greenwarrior/components/input_fields.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;

class AddStaffPage extends StatefulWidget {
  const AddStaffPage({super.key});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  String baseUrl = AppConfig.apiUrl;
  bool isLoading = false;
  TextEditingController empIdController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController confrimPassController = TextEditingController();
  bool? isSuperuser = false;
  bool? isZonalManager = false;
  bool? isMechanic = false;
  TextEditingController contactController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController remarkController = TextEditingController();

  Future<http.Response> createStaff(String body) async {
    var uri = Uri.parse("$baseUrl/test/employee/");
    var headers = {'Content-Type': 'application/json'};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addStaff() async {
    setState(() {
      isLoading = true;
    });
    String? empID = empIdController.text;
    String? name = nameController.text;
    String? password = passController.text;
    String? confirmPassword = confrimPassController.text;
    String? contact = contactController.text;
    String? address = addressController.text;
    String? remark = remarkController.text;
    String bodyParams;

    if (password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Please enter Password and Confirm Password'),
          duration: const Duration(seconds: 3),
        ),
      );
      // return;
    } else if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text("Passwords Don't Match"),
          duration: const Duration(seconds: 3),
        ),
      );
      // return;
    } else if (empID.isEmpty ||
        name.isEmpty ||
        contact.isEmpty ||
        address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text("Required * fields cannot be null"),
          duration: const Duration(seconds: 3),
        ),
      );
      // return;
    } else {
      bodyParams = jsonEncode({
        "password": password.toString(),
        "name": name.toString(),
        "employee_id": empID.toString(),
        "is_active": true,
        "is_superuser": isSuperuser,
        "is_zonal_manager": isZonalManager,
        "is_mechanic": isMechanic,
        "contact": contact.toString(),
        "address": address.toString(),
        "remark": remark.toString(),
      });
      var response = await createStaff(bodyParams);

      if (response.statusCode == 201) {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/staff_list');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: const Text("Unable to create Staff"),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() {
      isLoading = false;
    });

    // return;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text("Add Staff"),
          ),
          body: Card(
            margin: const EdgeInsets.all(15),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ),
              children: [
                // EMPLOYEE ID*
                const LabelText(text: "Employee ID*"),
                const SizedBox(height: 5),
                BasicInputField(
                  controller: empIdController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // NAME*
                const LabelText(text: "Name*"),
                const SizedBox(height: 5),
                BasicInputField(
                  controller: nameController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // PASSWORD*
                const LabelText(text: "Password*"),
                const SizedBox(height: 5),
                BasicInputField(
                  controller: passController,
                  obscureText: true,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // CONFIRM PASSWORD*
                const LabelText(text: "Confirm Password*"),
                const SizedBox(height: 5),
                BasicInputField(
                  controller: confrimPassController,
                  obscureText: true,
                  hintText: "Enter the same password as above.",
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // IS SUPERUSER
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isSuperuser,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          isSuperuser = val;
                        });
                      },
                    ),
                    const LabelText(text: "Is Superuser"),
                  ],
                ),

                // IS ZONAL MANAGER
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isZonalManager,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          isZonalManager = val;
                        });
                      },
                    ),
                    const LabelText(text: "Is Zonal Manager"),
                  ],
                ),

                // IS Mechanic
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isMechanic,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          isMechanic = val;
                        });
                      },
                    ),
                    const LabelText(text: "Is Mechanic"),
                  ],
                ),

                // CONTACT*
                const LabelText(text: "Contact*"),
                const SizedBox(height: 5),
                NumberField(
                  controller: contactController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // ADDRESS*
                const LabelText(text: "Address*"),
                const SizedBox(height: 5),
                TextAreaField(
                  controller: addressController,
                  padding: 10,
                ),
                const SizedBox(height: 10),

                // REMARK
                const LabelText(text: "Remark"),
                const SizedBox(height: 5),
                TextAreaField(
                  controller: remarkController,
                  padding: 10,
                ),
                const SizedBox(height: 20),

                // SUBMIT BUTTON
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(text: "Submit", onPressed: addStaff)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
