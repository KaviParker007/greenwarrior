import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/config.dart';
import 'package:greenwarrior/pages/job_cards/request_spare.dart';
import 'package:greenwarrior/pages/job_cards/start_job_card.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'add_job_card_detail.dart';
import 'approve_spare.dart';
import 'cancel_job_card.dart';
import 'end_job_card.dart';
import 'job_card_full_details_view.dart';

class JobCardListBuilder extends StatefulWidget {
  final List jobCard;
  const JobCardListBuilder({super.key, required this.jobCard});

  @override
  State<JobCardListBuilder> createState() => _VehiclesListBuilderState();
}

class _VehiclesListBuilderState extends State<JobCardListBuilder> with SingleTickerProviderStateMixin {
  late final controller = SlidableController(this);
  bool isLoading = false;

  void vehicleView(Map jobCardDetails) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobCardDetailsView(jobCardDetails: jobCardDetails)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.jobCard.length,
            itemBuilder: (context, index) {
              final jobCardDetails = widget.jobCard[index];
              return Slidable(
                key: const ValueKey(0),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    if (jobCardDetails["status"].toString().toLowerCase() == "Assigned".toLowerCase() ||
                        jobCardDetails["status"].toString().toLowerCase() == "Spare Allotted".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => StartJobCard(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.start,
                        label: 'Start',
                      ),
                    if (jobCardDetails["status"].toString().toLowerCase() == "Working".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RequestSpare(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.request_page_rounded,
                        label: 'Request Spare',
                      ),
                    if (jobCardDetails["status"].toString().toLowerCase() == "Spare Requested".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ApproveSpare(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icons.approval_outlined,
                        label: 'Approve Spare',
                      ),
                    if (jobCardDetails["status"].toString().toLowerCase() == "Working".toLowerCase())
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EndJobCard(jobCardId: jobCardDetails['id'])),
                          );
                          controller.close();
                        },
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        icon: Icons.stop,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        label: 'End',
                        // spacing: 8,
                      ),

                    SlidableAction(
                      onPressed: (_) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CancelJobCard(jobCardId: jobCardDetails['id'])),
                        );
                        controller.close();
                      },
                      backgroundColor: Theme.of(context).colorScheme.outline,
                      foregroundColor: Colors.black,
                      borderRadius: BorderRadius.circular(15),
                      icon: Icons.cancel,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      label: 'Cancel',
                      // spacing: 8,
                    )
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => vehicleView(jobCardDetails),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [

                          /// 🔹 VEHICLE NUMBER + STATUS CHIP
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                jobCardDetails['vehicle_number'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              buildStatusChip(
                                  jobCardDetails['status']),
                            ],
                          ),

                          const SizedBox(height: 10),

                          /// 🔹 WORK DESCRIPTION
                          Text(
                            jobCardDetails['work'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 6),

                          /// 🔹 ASSIGNED DATE
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 16,
                                  color: Colors.black54),
                              const SizedBox(width: 6),
                              Text(
                                jobCardDetails['assigned_on'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              );
            });
  }

  Widget buildStatusChip(String status) {
    Color chipColor;

    switch (status.toLowerCase()) {
      case "assigned":
        chipColor = Colors.blue;
        break;
      case "working":
        chipColor = Colors.orange;
        break;
      case "spare requested":
        chipColor = Colors.purple;
        break;
      case "spare allotted":
        chipColor = Colors.green;
        break;
      case "completed":
        chipColor = Colors.teal;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(
            color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
    );
  }

}

class JobCardList extends StatefulWidget {
  const JobCardList({super.key});

  @override
  State<JobCardList> createState() => _VehiclesListState();
}

class _VehiclesListState extends State<JobCardList> {
  bool isLoggedIn = false;
  bool isLoading = false;
  String baseUrl = AppConfig.apiUrl;
  String? username;
  String? password;
  List jobCard = [];
  List filteredJobCard = []; // ✅ new list for filtered data

  bool isSearching = false; // ✅ toggles search bar
  TextEditingController searchController = TextEditingController(); // ✅ controller for search bar


  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> getJobCardList() async {
    setState(() {
      isLoading = true;
      jobCard = [];
      filteredJobCard = [];
    });

    var uri = Uri.parse("$baseUrl/drf-job-card-list/");
    var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    var headers = {'Content-Type': 'application/json', 'authorization': auth};

    try {
      var response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        setState(() {
          jobCard = decoded;
          filteredJobCard = decoded; // ✅ Initialize filtered list
        });
      } else {
        errorMsg("500 - Server Error");
      }
    } catch (e) {
      errorMsg("Error - $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void filterSearch(String query) {
    setState(() {
      filteredJobCard = jobCard
          .where((item) => item['vehicle_number']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase()))
          .toList();
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

  void checkLoginStatus() async {
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
    await getJobCardList();
  }

  Widget buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: searchController,
        style: TextStyle(
            color: Colors.black54
        ),
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search vehicle number...',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          contentPadding:
          EdgeInsets.symmetric(horizontal: 10),
        ),
        onChanged: filterSearch,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return !isLoggedIn
        ? const LoginPage()
        : GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xffF4F6FA),

        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: isSearching
              ? buildSearchField()
              : const Text(
            "Job Card List",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isSearching ? Icons.close : Icons.search,
                color: Colors.black87,
              ),
              onPressed: () {
                setState(() {
                  if (isSearching) {
                    searchController.clear();
                    filteredJobCard = jobCard;
                  }
                  isSearching = !isSearching;
                });
              },
            ),
          ],
        ),

        drawer: const AppDrawer(),

        body: Visibility(
          visible: !isLoading,
          replacement: const Center(
            child: CircularProgressIndicator(),
          ),
          child: RefreshIndicator(
            onRefresh: getJobCardList,
            child:
            JobCardListBuilder(jobCard: filteredJobCard),
          ),
        ),

        floatingActionButton:
        FloatingActionButton.extended(
          backgroundColor:
          Theme.of(context).colorScheme.primary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                  const AddJobCardDetail()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("Add Job Card"),
        ),
      ),
    );

  }
}
