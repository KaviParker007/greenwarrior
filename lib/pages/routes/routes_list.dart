import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/config.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class RoutesListBuilder extends StatefulWidget {
  final List routes;
  const RoutesListBuilder({super.key, required this.routes});

  @override
  State<RoutesListBuilder> createState() => _RoutesListBuilderState();
}

class _RoutesListBuilderState extends State<RoutesListBuilder>
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
            itemCount: widget.routes.length,
            itemBuilder: (context, index) {
              final route = widget.routes[index];
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
                    title: Text(route['route']),
                  ),
                ),
              );
            });
  }
}

class RoutesList extends StatefulWidget {
  const RoutesList({super.key});

  @override
  State<RoutesList> createState() => _RoutesListState();
}

class _RoutesListState extends State<RoutesList> {
  bool isLoggedIn = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List routes = [];

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getRoutesList() async {
    var uri = Uri.parse("$baseUrl/test/route/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'Authorization': auth};
    try {
      var response = await http.get(
        uri,
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          routes = jsonDecode(response.body);
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
    await prefs.setString("menu", "routes");
    String? user = prefs.getString('username');
    String? pass = prefs.getString('password');
    if (user != null && pass != null) {
      setState(() {
        isLoggedIn = true;
        username = user;
        password = pass;
      });
    }
    await getRoutesList();
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
                title: const Text("Routes List"),
              ),
              drawer: const AppDrawer(),
              body: Visibility(
                visible: routes != [],
                replacement: const Center(
                  child: CircularProgressIndicator(),
                ),
                child: RefreshIndicator(
                  onRefresh: getRoutesList,
                  child: RoutesListBuilder(routes: routes),
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
