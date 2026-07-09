import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/config.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class WardListBuilder extends StatefulWidget {
  final List wards;
  const WardListBuilder({super.key, required this.wards});

  @override
  State<WardListBuilder> createState() => _WardListBuilderState();
}

class _WardListBuilderState extends State<WardListBuilder>
    with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.wards.length,
            itemBuilder: (context, index) {
              final ward = widget.wards[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    // EDIT BUTTON
                    SlidableAction(
                      onPressed: (_) => controller.close(),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icons.edit,
                      label: 'Edit',
                    ),

                    // DEACTIVATE BUTTON
                    SlidableAction(
                      onPressed: (_) => controller.close(),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      icon: Icons.person_off_rounded,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      label: 'Deactivate',
                      // spacing: 8,
                    )
                  ],
                ),
                child: Card(
                  child: ListTile(
                    title: Text(ward['ward_code']),
                    subtitle: Text(ward['ward_name']),
                  ),
                ),
              );
            });
  }
}

class WardList extends StatefulWidget {
  const WardList({super.key});

  @override
  State<WardList> createState() => _WardListState();
}

class _WardListState extends State<WardList> {
  bool isLoggedIn = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List wards = [];

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getWardList() async {
    var uri = Uri.parse("$baseUrl/test/ward/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};
    try {
      var response = await http.get(
        uri,
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          wards = jsonDecode(response.body);
        });
      } else {
        // print('Failed response: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(response.body.toString()),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      // print('Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(e.toString()),
        duration: const Duration(seconds: 10),
      ));
    }
  }

  void checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "wards");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getWardList();
  }

  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: const Text("Wards List"),
              ),
              drawer: const AppDrawer(),
              body: Visibility(
                visible: wards != [],
                replacement: const Center(
                  child: CircularProgressIndicator(),
                ),
                child: RefreshIndicator(
                  onRefresh: getWardList,
                  child: WardListBuilder(wards: wards),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          );
  }
}
