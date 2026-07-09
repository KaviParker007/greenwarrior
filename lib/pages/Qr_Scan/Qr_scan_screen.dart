// lib/screens/qr_scan/qr_scanner_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_theme.dart';
import '../../components/common/loading_overlay.dart';
import '../../config.dart';
import '../../services/auth_service.dart';
import 'bin_collection.dart';
import 'bin_data_model.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  BinData? _scannedData;
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  String? _username;
  String? _password;
  String? _deviceId;
  String? _accesstoken;
  String? _refreshtoken;

  late final MobileScannerController _cameraController;
  late final AnimationController _animationController;
  late final Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeControllers();
    _getCredentials();
  }

  void _initializeControllers() {
    _cameraController = MobileScannerController(
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
      _password = prefs.getString('password');
      _deviceId = prefs.getString('deviceId');
      _accesstoken = prefs.getString('access_token');
      _refreshtoken = prefs.getString('refresh_token');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _cameraController.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _cameraController.stop();
        break;
      case AppLifecycleState.hidden:
      // Handle hidden state - usually just do nothing or stop camera
        _cameraController.stop();
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    // Guard against duplicate/overlapping detections. `_isProcessing` is a
    // synchronous flag that blocks re-entry before the async setState settles.
    if (!_isScanning || _isProcessing || !mounted) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('QR content is not a bin object');
      }

      final data = BinData.fromJson(decoded);
      if (data.id == null || data.id == 0) {
        throw const FormatException('QR code is missing a valid bin id');
      }

      setState(() {
        _scannedData = data;
        _isScanning = false;
      });

      _cameraController.stop();

      if (data.isLocationMissing) {
        _fetchCurrentLocation();
      }

      _showSuccessHaptic();
    } catch (_) {
      // Invalid/unsupported QR: keep scanning and let the user try again.
      _isProcessing = false;
      _showError('Invalid or unsupported QR code');
    }
  }

  Future<void> _showSuccessHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable GPS.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission permanently denied. Enable it from app settings.';
      }
      if (![LocationPermission.always, LocationPermission.whileInUse]
          .contains(permission)) {
        throw 'Location permission denied';
      }


      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String? address = "Location captured";
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = "${place.street}, ${place.locality}";
        }
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _scannedData = _scannedData!
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..location = _scannedData!.location?.isNotEmpty == true
              ? _scannedData!.location
              : address;
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      print('Location error: $e');
      _showError('Location error: $e');
    }
  }

  Future<void> _submitCollection() async {
    if (_scannedData == null) return;

    setState(() => _isSubmitting = true);

    try {
      final Uri url =
      Uri.parse('${AppConfig.apiUrl}/d2d/drf_collect_house/');

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (_accesstoken != null)
          'Authorization': 'Bearer $_accesstoken',
      };

      final body = {
        'house_id': _scannedData!.id,
        'device_id': _deviceId ?? '',
        'latitude': _scannedData!.latitude?.toStringAsFixed(6),
        'longitude': _scannedData!.longitude?.toStringAsFixed(6),
      };

      http.Response response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      print('____mmmbody');
      print(url);
      print(body);
      print(_accesstoken);
      print(response.statusCode);
      print(response.body);


      /// 🔥 IF ACCESS TOKEN EXPIRED
      if (response.statusCode == 401) {

        bool refreshed = await AuthService.refreshAccessToken();

        if (!refreshed) {
          _showError("Session expired. Please login again.");
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
          return;
        }

        // Get new access token
        final prefs = await SharedPreferences.getInstance();
        _accesstoken = prefs.getString('access_token');

        headers['Authorization'] = 'Bearer $_accesstoken';

        // Retry request
        response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        _showSuccessDialog();
      } else {
        final error = jsonDecode(response.body);
        _showError(error['detail'] ?? 'Submission failed');
      }

    } catch (e) {
      _showError('Network error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
             Text(
              'Success!',
              style: GoogleFonts.poppins(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content:  Text(
          'Collection submitted successfully!',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.black
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BinCollectionScreen(),
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  void _resetScan() {
    setState(() {
      _scannedData = null;
      _isScanning = true;
      _isProcessing = false;
      _isLoadingLocation = false;
    });
    _cameraController.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSubmitting,
      message: 'Submitting collection...',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            if (_isScanning) _buildScannerView(),
            if (!_isScanning && _scannedData != null) _buildResultView(),
          ],
        ),
      ),
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
        title:  Text('Scan QR Code',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),

      ),
        )
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = isPermission
        ? 'Camera permission is required to scan QR codes.'
        : 'Unable to start the camera. Please try again.';

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isPermission) {
                    openAppSettings();
                  } else {
                    _cameraController.start();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isPermission ? 'Open Settings' : 'Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _onDetect,
          fit: BoxFit.cover,
          errorBuilder: (context, error) => _buildCameraError(error),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.8),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 10 + (_scanLineAnimation.value * 260),
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.greenAccent,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child:  Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text(
                      "Align QR code within frame",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F7FA), Color(0xFFE4E8F0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildSuccessHeader(),
                    const SizedBox(height: 24),
                    _buildDataCard(),
                    const SizedBox(height: 20),
                    if (_isLoadingLocation) _buildLocationLoader(),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
         Text(
          AppStrings.binDetected,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.green
          ),
        ),
         Text(
          'Scan successful',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDataCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('House ID', '#${_scannedData!.id}'),
          const Divider(height: 24),
          if (_scannedData!.latitude != null)
            _buildLocationInfo(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
              color: Colors.black54
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          'Location Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black54
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scannedData!.location ?? 'Location captured',
                      style: GoogleFonts.poppins(fontSize: 13,
                        color: Colors.black54
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCoordinateChip(
                    'Lat',
                    _scannedData!.latitude!.toStringAsFixed(6),
                  ),
                  _buildCoordinateChip(
                    'Lng',
                    _scannedData!.longitude!.toStringAsFixed(6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinateChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.poppins(fontSize: 11,color: Colors.black54),
      ),
    );
  }

  Widget _buildLocationLoader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Fetching location...'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _resetScan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.white,
                foregroundColor: Colors.green
              ),
              child:  Text('Scan Again',style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitCollection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white
              ),
              child:  Text(
               'Submit',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}