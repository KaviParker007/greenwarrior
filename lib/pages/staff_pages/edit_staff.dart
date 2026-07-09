import "dart:convert";
import "package:flutter/material.dart";
import "package:greenwarrior/components/buttons.dart";
import "package:greenwarrior/components/input_fields.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;
import "package:greenwarrior/pages/staff_pages/staff_view.dart";

class EditStaffPage extends StatefulWidget {
  final int userId;
  final bool staffViewRedirect;
  const EditStaffPage({
    super.key,
    required this.userId,
    this.staffViewRedirect = false,
  });

  @override
  State<EditStaffPage> createState() => _EditStaffPageState();
}

class _EditStaffPageState extends State<EditStaffPage> {
  String baseUrl = AppConfig.apiUrl;
  bool isLoading = false;
  bool gotUser = false;
  Map staff = {};
  TextEditingController empIdController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  bool? isSuperuser = false;
  bool? isZonalManager = false;
  bool? isMechanic = false;
  TextEditingController contactController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController remarkController = TextEditingController();

  Future<http.Response> updateStaff(String body) async {
    var uri = Uri.parse("$baseUrl/test/employee/${widget.userId}/");
    var headers = {'Content-Type': 'application/json'};
    var response = await http.put(uri, headers: headers, body: body);
    return response;
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

  void getUser(int id) async {
    setState(() {
      gotUser = false;
    });
    var uri = Uri.parse("$baseUrl/test/employee/$id/");
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      setState(() {
        staff = jsonDecode(response.body);
        empIdController.text = staff['employee_id'];
        nameController.text = staff['name'];
        isSuperuser = staff['is_superuser'];
        isZonalManager = staff['is_zonal_manager'];
        isMechanic = staff['is_mechanic'];
        contactController.text = staff['contact'];
        addressController.text = staff['address'];
        remarkController.text = staff['remark'];
      });
    } else {
      errorMsg("Unable to find User");
      Navigator.pop(context);
      Navigator.pushNamed(context, "/staff_list");
    }
    setState(() {
      gotUser = true;
    });
  }

  @override
  void initState() {
    super.initState();
    getUser(widget.userId);
  }

  void editStaff() async {
    setState(() {
      isLoading = true;
    });
    String? empID = empIdController.text;
    String? name = nameController.text;
    String? contact = contactController.text;
    String? address = addressController.text;
    // String? remark = remarkController.text;
    String bodyParams;

    if (empID.isEmpty || name.isEmpty || contact.isEmpty || address.isEmpty) {
      errorMsg("Required * fields cannot be null");
      // return;
    } else {
      staff['employee_id'] = empIdController.text.toString();
      staff['name'] = nameController.text.toString();
      staff['is_superuser'] = isSuperuser;
      staff['is_zonal_manager'] = isZonalManager;
      staff['is_mechanic'] = isMechanic;
      staff['contact'] = contactController.text.toString();
      staff['address'] = addressController.text.toString();
      staff['remark'] = remarkController.text.toString();
      staff.remove("image");

      bodyParams = jsonEncode(staff);
      // print(bodyParams);
      var response = await updateStaff(bodyParams);
      // print(response.body);

      if (response.statusCode == 200) {
        Navigator.pop(context);
        if (widget.staffViewRedirect) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => StaffView(userId: staff['id'])),
          );
        } else {
          Navigator.pushNamed(context, "/staff_list");
        }
      } else {
        errorMsg("Unable to edit Staff");
      }
    }

    setState(() {
      isLoading = false;
    });

    return;
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
            title: const Text("Edit Staff"),
          ),
          body: !gotUser
              ? const Center(child: CircularProgressIndicator())
              : Card(
                  margin: const EdgeInsets.all(15),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 10,
                    ),
                    children: [
                      // EMPLOYEE ID*
                      // LabelText(text: widget.userId),
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
                          : PrimaryButton(text: "Submit", onPressed: editStaff)
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
