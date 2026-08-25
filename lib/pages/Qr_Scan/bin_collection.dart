// lib/pages/Qr_Scan/bin_collection.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/gradient_app_bar.dart';
import '../../components/common/responsive_card_grid.dart';
import '../../components/common/state_views.dart';
import '../../components/d2d/collection_card.dart';
import '../../components/drawer_page.dart';
import '../../constants/app_theme.dart';
import '../../models/house_collection.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/collection_scan_service.dart';
import 'qr_scan_screen.dart';

/// Scan flow home: the collections recorded from this device, plus the entry
/// point into the QR scanner.
class BinCollectionScreen extends StatefulWidget {
  const BinCollectionScreen({super.key});

  @override
  State<BinCollectionScreen> createState() => _BinCollectionScreenState();
}

class _BinCollectionScreenState extends State<BinCollectionScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  List<HouseCollection> _collections = const [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSessionError = false;
  String? _username;

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

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadUser();
    await _fetchCollections();
  }

  Future<void> _loadUser() async {
    final name = await AuthService.currentUsername();
    if (!mounted) return;
    setState(() => _username = name);
  }

  Future<void> _fetchCollections() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSessionError = false;
    });

    try {
      final collections = await CollectionScanService.listRecentCollections();
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final expired = error is SessionExpiredException;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
        _isSessionError = expired;
      });
      if (expired) _handleSessionExpired();
    }
  }

  Future<void> _handleSessionExpired() async {
    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login_page', (route) => false);
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    ).then((_) => _fetchCollections());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      drawer: _username != null
          ? const AppDrawer(activeMenu: DrawerMenu.collections)
          : null,
      appBar: GradientAppBar(
        title: 'Collections',
        icon: Icons.recycling,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchCollections,
          ),
        ],
      ),
      floatingActionButton: _buildFloatingButton(),
      body: RefreshIndicator(
        onRefresh: _fetchCollections,
        color: AppTheme.accentColor,
        child: SectionStateView(
          isLoading: _isLoading && _collections.isEmpty,
          errorMessage: _errorMessage,
          isSessionError: _isSessionError,
          isEmpty: _collections.isEmpty,
          onRetry: _isSessionError ? _handleSessionExpired : _fetchCollections,
          emptyIcon: Icons.recycling,
          emptyTitle: AppStrings.noCollections,
          emptyMessage: AppStrings.startScanning,
          emptyAction: ElevatedButton.icon(
            onPressed: _navigateToScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text(AppStrings.scanNow),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
            ),
          ),
          contentBuilder: (context) => CenteredContent(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _collections.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CollectionCard(collection: _collections[index]),
              ),
            ),
          ),
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
        label: Text(
          AppStrings.scanBin,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
