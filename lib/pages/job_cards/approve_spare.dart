import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:greenwarrior/components/buttons.dart";
import "package:greenwarrior/components/input_fields.dart";
import "package:greenwarrior/components/label.dart";
import "package:greenwarrior/config.dart";
import 'package:http/http.dart' as http;
import "package:greenwarrior/pages/login.dart";

class ApproveSpare extends StatefulWidget {
  final int jobCardId;
  const ApproveSpare({super.key, required this.jobCardId});

  @override
  State<ApproveSpare> createState() => _ApproveSpareState();
}

class _ApproveSpareState extends State<ApproveSpare> {
  bool isLoggedIn = false;
  bool isLoading = false;
  bool isStarting = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  TextEditingController spareController = TextEditingController();
  TextEditingController spareCodeController = TextEditingController();
  TextEditingController costController = TextEditingController();
  TextEditingController remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<http.Response> approveSpareDetails(String body) async {
    var uri = Uri.parse("$baseUrl/drf-approve-spare/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    var response = await http.post(uri, headers: headers, body: body);
    return response;
  }

  void addSpareDetail() async {
    setState(() {
      isLoading = true;
    });
    String? spare = spareController.text;
    String? spareCode = spareCodeController.text;
    double? cost = costController.text.isNotEmpty ? double.parse(costController.text) : null;
    String? remark = remarkController.text;

    var body = {
        "id": widget.jobCardId,
        "spares": spare,
        "spare_code": spareCode,
        "cost": cost,
        "spare_approval_remark": remark
      };
      var response = await approveSpareDetails(jsonEncode(body));
      if (response.statusCode == 200) {
        successMsg('Spare Approved successfully');
        Navigator.pop(context);
        Navigator.pushNamed(context, '/job_card_list');
      } else {
        print(response.body);
        errorMsg("Unable to approve spare");
      }

    setState(() {
      isLoading = false;
    });
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
              "Approve Spare",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ================= SPARE DETAILS =================
              sectionTitle(
                  "Spare Details",
                  Icons.settings),

              styledCard(
                child: Column(
                  children: [

                    TextField(
                      controller:
                      spareController,
                      style: TextStyle(
                          color: Colors.black54
                      ),                      decoration:
                      inputDecoration(
                          hint:
                          "Spare Name"),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                      spareCodeController,
                      style: TextStyle(
                          color: Colors.black54
                      ),
                      decoration:
                      inputDecoration(
                          hint:
                          "Spare Code"),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                      costController,
                      style: TextStyle(
                          color: Colors.black54
                      ),
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      inputDecoration(
                          hint:
                          "Cost"),
                    ),
                  ],
                ),
              ),

              // ================= REMARK =================
              sectionTitle(
                  "Approval Remark",
                  Icons.note_alt),

              styledCard(
                child: TextField(
                  controller:
                  remarkController,
                  style: TextStyle(
                      color: Colors.black54
                  ),
                  maxLines: null,
                  decoration:
                  inputDecoration(
                      hint:
                      "Spare Approval Remark"),
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
                  "Approve Spare",
                  onPressed:
                  addSpareDetail,
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
