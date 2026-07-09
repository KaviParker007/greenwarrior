// lib/screens/qr_scan/bin_collection.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../components/drawer_page.dart';
import '../../constants/app_theme.dart';

import '../../components/common/loading_shimmer.dart';

import '../../config.dart';

import '../../services/auth_service.dart';
import 'Qr_scan_screen.dart';
import 'bin_data_Model.dart';


class BinCollectionScreen extends StatefulWidget {
  const BinCollectionScreen({super.key});

  @override
  State<BinCollectionScreen> createState() => _BinCollectionScreenState();
}

class _BinCollectionScreenState extends State<BinCollectionScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  List<HouseCollection> _collections = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _userid;
  String? _username;
  String? _password;
  String? _accesstoken;
  String? _refreshtoken;

  late final AnimationController _fabAnimationController;
  late final Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
    _fabAnimationController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getCredentials();
    await _fetchCollections();
  }

  Future<void> _getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("menu", "bin_collections");
    setState(() {
      _userid = prefs.getInt('userid');
      _username = prefs.getString('username');
      _password = prefs.getString('password');
      _accesstoken = prefs.getString('access_token');
      _refreshtoken = prefs.getString('refresh_token');

    });
  }

  Future<void> _fetchCollections() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('access_token');

      final Uri url =
      Uri.parse('${AppConfig.apiUrl}/d2d/drf_list_collection_all_temp/');

      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        if (accessToken != null)
          'Authorization': 'Bearer $accessToken',
      };

      http.Response response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      /// 🔥 If access token expired
      if (response.statusCode == 401) {
        print("Access token expired. Refreshing...");

        bool refreshed = await AuthService.refreshAccessToken();

        if (refreshed) {
          // Get new access token
          accessToken = prefs.getString('access_token');

          headers['Authorization'] = 'Bearer $accessToken';
          // Retry original request
          response = await http.get(url, headers: headers);
        } else {
          _showError('Session expired. Please login again.');

        }
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        setState(() {
          _collections =
              jsonList.map((e) => HouseCollection.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _showError(_errorMessage.toString());
      });
    }
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    ).then((_) => _fetchCollections());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      drawer: _username != null ? const AppDrawer() : null,
      body: RefreshIndicator(
        onRefresh: _fetchCollections,
        color: AppTheme.accentColor,
        child: _buildBody(),
      ),
      floatingActionButton: _buildFloatingButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration:  BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.recycling, color: Colors.white),
              ),
              const SizedBox(width: 12),
               Text(
                "Collections",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchCollections,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: _navigateToScanner,
        backgroundColor: AppTheme.accentColor,
        icon: const Icon(Icons.qr_code_scanner),
        label:  Text(
          "Scan Bin",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _collections.isEmpty) {
      return const LoadingShimmer();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_collections.isEmpty) {
      return _buildEmptyView();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final collection = _collections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCollectionCard(collection),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 50,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style:  GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCollections,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.recycling,
              size: 80,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.noCollections,
            style:  GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.startScanning,
            style: GoogleFonts.poppins(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text(AppStrings.scanNow),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(HouseCollection collection) {
    final hasLocation =
        collection.latitude != null && collection.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.green.shade100,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// TOP ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Collection Id #${collection.id}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasLocation
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasLocation ? "GPS Captured" : "No GPS",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasLocation ? Colors.green : Colors.red,
                    ),
                  ),
                )
              ],
            ),

            const SizedBox(height: 12),

            /// HOUSE NAME
            Row(
              children: [
                const Icon(Icons.home, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    collection.houseName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// INFO ROWS
            _infoRow(Icons.map, "Ward: ${collection.wardCode}"),
            _infoRow(Icons.business, "Project: ${collection.projectCode}"),
            _infoRow(Icons.person, "Collected By: ${collection.collectedByName}"),
            _infoRow(Icons.phone_android, "Device: ${collection.deviceId}"),

            const SizedBox(height: 10),

            /// DATE
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  formattedDate(collection.collectedOn),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            if (hasLocation) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    "${collection.latitude}, ${collection.longitude}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  String formattedDate(String rawDate) {
    final date = DateTime.parse(rawDate);
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }
}