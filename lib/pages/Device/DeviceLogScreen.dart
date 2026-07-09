import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config.dart';

class DeviceLogScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const DeviceLogScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceLogScreen> createState() => _DeviceLogScreenState();
}

class _DeviceLogScreenState extends State<DeviceLogScreen> {
  List deviceLogs = [];
  List filteredLogs = [];
  bool isLoading = true;
  String? username;
  String? password;
  String baseUrl = AppConfig.apiUrl;
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndFetchLogs();
  }

  Future<void> _loadCredentialsAndFetchLogs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username');
      password = prefs.getString('password');
    });
    await _fetchDeviceLogs();
  }

  Future<void> _fetchDeviceLogs() async {
    setState(() {
      isLoading = true;
    });

    try {
      var uri = Uri.parse("$baseUrl/drf-device-log/");
      var auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      var headers = {'Content-Type': 'application/json', 'authorization': auth};
      var body = jsonEncode({'deviceid': widget.deviceId});

      var response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        setState(() {
          deviceLogs = jsonDecode(response.body);
          filteredLogs = List.from(deviceLogs);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load logs: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterLogs(String query) {
    setState(() {
      filteredLogs = deviceLogs.where((log) {
        final name = log['name'].toString().toLowerCase();
        final userId = log['userid'].toString().toLowerCase();
        final searchLower = query.toLowerCase();

        return name.contains(searchLower) || userId.contains(searchLower);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      if (isSearching) {
        searchController.clear();
        filteredLogs = List.from(deviceLogs);
      }
      isSearching = !isSearching;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
          controller: searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by name or employee code...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: _filterLogs,
        )
            : Text('${widget.deviceName} Logs'),
        actions: [
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDeviceLogs,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredLogs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No matching logs found'
                  : 'No logs available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            if (isSearching)
              TextButton(
                onPressed: () {
                  _toggleSearch();
                },
                child: Text('Clear search'),
              ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredLogs.length,
        itemBuilder: (context, index) {
          final log = filteredLogs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLogRow('EMPLOYEE CODE', log['userid']),
                  _buildLogRow(
                      'VERIFICATION CODE', log['verifymethodname']),
                  _buildLogRow('TIME', log['logdate']),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.37,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}