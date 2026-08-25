import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/gradient_app_bar.dart';
import '../../components/common/responsive_card_grid.dart';
import '../../components/common/state_views.dart';
import '../../components/d2d/collection_card.dart';
import '../../components/d2d/summary_card.dart';
import '../../components/drawer_page.dart';
import '../../components/inputs/date_field.dart';
import '../../constants/app_theme.dart';
import '../../models/collection_summary.dart';
import '../../models/house_collection.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/d2d_service.dart';
import '../../utils/api_date.dart';

/// Load state for one dashboard section.
///
/// Keeping the four flags together lets every tab share [SectionStateView]
/// instead of repeating loading/error/empty handling.
class _Section<T> {
  List<T> items = const [];
  bool isLoading = false;
  bool isLoaded = false;
  String? error;
  bool isSessionError = false;

  bool get isEmpty => items.isEmpty;

  /// Marks the data stale so the next visit refetches it.
  void invalidate() {
    isLoaded = false;
    error = null;
    isSessionError = false;
  }
}

/// D2D collection dashboard.
///
/// Four tabs follow the API's own hierarchy: project summaries, zone summaries,
/// ward summaries, and the queried-collections list. Selecting a level scopes
/// the next one, matching the `Project -> Zone -> Ward` filter flow.
class D2dDashboardPage extends StatefulWidget {
  const D2dDashboardPage({super.key});

  @override
  State<D2dDashboardPage> createState() => _D2dDashboardPageState();
}

class _D2dDashboardPageState extends State<D2dDashboardPage>
    with SingleTickerProviderStateMixin {
  static const int _tabProjects = 0;
  static const int _tabZones = 1;
  static const int _tabWards = 2;
  static const int _tabCollections = 3;

  late final TabController _tabController;
  int _currentTab = _tabProjects;

  /// Date applied to the three summary endpoints.
  DateTime _summaryDate = ApiDate.today();

  /// Range applied to the queried-collections endpoint.
  DateTime _rangeStart = ApiDate.today();
  DateTime _rangeEnd = ApiDate.today();

  CollectionSummary? _selectedProject;
  CollectionSummary? _selectedZone;
  CollectionSummary? _selectedWard;

  final _Section<CollectionSummary> _projects = _Section<CollectionSummary>();
  final _Section<CollectionSummary> _zones = _Section<CollectionSummary>();
  final _Section<CollectionSummary> _wards = _Section<CollectionSummary>();
  final _Section<HouseCollection> _collections = _Section<HouseCollection>();

  String? _username;

  /// Prevents several failing sections from each pushing the login route.
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
    _restoreHeader();
    _loadProjects();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _restoreHeader() async {
    final name = await AuthService.currentUsername();
    if (!mounted) return;
    setState(() => _username = name);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_currentTab == _tabController.index) return;
    setState(() => _currentTab = _tabController.index);
    _ensureLoaded(_currentTab);
  }

  /// Fetches a tab's data only when it is stale and not already in flight, so
  /// switching tabs never fires a duplicate request.
  void _ensureLoaded(int tab) {
    switch (tab) {
      case _tabProjects:
        _loadProjects();
      case _tabZones:
        _loadZones();
      case _tabWards:
        _loadWards();
      case _tabCollections:
        _loadCollections();
    }
  }

  // ----------------------------------------------------------------- loads ---

  Future<void> _loadProjects({bool force = false}) async {
    if (_projects.isLoading || (_projects.isLoaded && !force)) return;
    setState(() {
      _projects.isLoading = true;
      _projects.error = null;
    });
    try {
      final items =
          await D2dService.collectionByProject(collectedDate: _summaryDate);
      if (!mounted) return;
      setState(() {
        _projects
          ..items = items
          ..isLoading = false
          ..isLoaded = true;
      });
    } on ApiException catch (error) {
      _handleSectionError(_projects, error);
    }
  }

  Future<void> _loadZones({bool force = false}) async {
    if (_zones.isLoading || (_zones.isLoaded && !force)) return;
    setState(() {
      _zones.isLoading = true;
      _zones.error = null;
    });
    try {
      final items = await D2dService.collectionByZone(
        collectedDate: _summaryDate,
        projectId: _selectedProject?.id,
      );
      if (!mounted) return;
      setState(() {
        _zones
          ..items = items
          ..isLoading = false
          ..isLoaded = true;
      });
    } on ApiException catch (error) {
      _handleSectionError(_zones, error);
    }
  }

  Future<void> _loadWards({bool force = false}) async {
    if (_wards.isLoading || (_wards.isLoaded && !force)) return;
    setState(() {
      _wards.isLoading = true;
      _wards.error = null;
    });
    try {
      final items = await D2dService.collectionByWard(
        collectedDate: _summaryDate,
        zoneId: _selectedZone?.id,
      );
      if (!mounted) return;
      setState(() {
        _wards
          ..items = items
          ..isLoading = false
          ..isLoaded = true;
      });
    } on ApiException catch (error) {
      _handleSectionError(_wards, error);
    }
  }

  Future<void> _loadCollections({bool force = false}) async {
    if (_collections.isLoading || (_collections.isLoaded && !force)) return;
    setState(() {
      _collections.isLoading = true;
      _collections.error = null;
    });
    try {
      final items = await D2dService.queriedCollections(
        startDate: _rangeStart,
        endDate: _rangeEnd,
        projectId: _selectedProject?.id,
        zoneId: _selectedZone?.id,
        wardId: _selectedWard?.id,
      );
      if (!mounted) return;
      setState(() {
        _collections
          ..items = items
          ..isLoading = false
          ..isLoaded = true;
      });
    } on ApiException catch (error) {
      _handleSectionError(_collections, error);
    }
  }

  void _handleSectionError<T>(_Section<T> section, ApiException error) {
    if (!mounted) return;
    final expired = error is SessionExpiredException;
    setState(() {
      section
        ..isLoading = false
        ..isLoaded = false
        ..error = error.message
        ..isSessionError = expired;
    });
    if (expired) _handleSessionExpired();
  }

  Future<void> _handleSessionExpired() async {
    if (_redirectingToLogin) return;
    _redirectingToLogin = true;

    await AuthService.clearSession();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Your session has expired. Please log in again.'),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login_page',
      (route) => false,
    );
  }

  // ------------------------------------------------------------ selections ---

  void _onSummaryDateChanged(DateTime date) {
    setState(() {
      _summaryDate = date;
      _projects.invalidate();
      _zones.invalidate();
      _wards.invalidate();
    });
    _ensureLoaded(_currentTab);
  }

  void _onRangeStartChanged(DateTime date) {
    final clampedEnd = ApiDate.clampEnd(date, _rangeEnd);
    final wasClamped = clampedEnd != _rangeEnd;
    setState(() {
      _rangeStart = date;
      _rangeEnd = clampedEnd.isBefore(date) ? date : clampedEnd;
      _collections.invalidate();
    });
    if (wasClamped) _showRangeLimitNotice();
    _loadCollections();
  }

  void _onRangeEndChanged(DateTime date) {
    final clampedStart = ApiDate.clampStart(_rangeStart, date);
    final wasClamped = clampedStart != _rangeStart;
    setState(() {
      _rangeEnd = date;
      _rangeStart = clampedStart.isAfter(date) ? date : clampedStart;
      _collections.invalidate();
    });
    if (wasClamped) _showRangeLimitNotice();
    _loadCollections();
  }

  void _showRangeLimitNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'The date range is limited to ${ApiDate.maxRangeInDays} days.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _selectProject(CollectionSummary project) {
    setState(() {
      final isSame = _selectedProject?.id == project.id;
      _selectedProject = isSame ? null : project;
      // A different project invalidates anything scoped beneath it.
      _selectedZone = null;
      _selectedWard = null;
      _zones.invalidate();
      _wards.invalidate();
      _collections.invalidate();
    });
    if (_selectedProject != null) {
      _tabController.animateTo(_tabZones);
      setState(() => _currentTab = _tabZones);
    }
    _ensureLoaded(_currentTab);
  }

  void _selectZone(CollectionSummary zone) {
    setState(() {
      final isSame = _selectedZone?.id == zone.id;
      _selectedZone = isSame ? null : zone;
      _selectedWard = null;
      _wards.invalidate();
      _collections.invalidate();
    });
    if (_selectedZone != null) {
      _tabController.animateTo(_tabWards);
      setState(() => _currentTab = _tabWards);
    }
    _ensureLoaded(_currentTab);
  }

  void _selectWard(CollectionSummary ward) {
    setState(() {
      final isSame = _selectedWard?.id == ward.id;
      _selectedWard = isSame ? null : ward;
      _collections.invalidate();
    });
    if (_selectedWard != null) {
      _tabController.animateTo(_tabCollections);
      setState(() => _currentTab = _tabCollections);
    }
    _ensureLoaded(_currentTab);
  }

  void _clearProject() {
    setState(() {
      _selectedProject = null;
      _selectedZone = null;
      _selectedWard = null;
      _zones.invalidate();
      _wards.invalidate();
      _collections.invalidate();
    });
    _ensureLoaded(_currentTab);
  }

  void _clearZone() {
    setState(() {
      _selectedZone = null;
      _selectedWard = null;
      _wards.invalidate();
      _collections.invalidate();
    });
    _ensureLoaded(_currentTab);
  }

  void _clearWard() {
    setState(() {
      _selectedWard = null;
      _collections.invalidate();
    });
    _ensureLoaded(_currentTab);
  }

  Future<void> _refreshCurrentTab() async {
    switch (_currentTab) {
      case _tabProjects:
        await _loadProjects(force: true);
      case _tabZones:
        await _loadZones(force: true);
      case _tabWards:
        await _loadWards(force: true);
      case _tabCollections:
        await _loadCollections(force: true);
    }
  }

  // ------------------------------------------------------------------- ui ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      drawer: _username != null
          ? const AppDrawer(activeMenu: DrawerMenu.dashboard)
          : null,
      appBar: GradientAppBar(
        title: 'D2D Dashboard',
        icon: Icons.dashboard_rounded,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshCurrentTab,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Projects'),
            Tab(text: 'Zones'),
            Tab(text: 'Wards'),
            Tab(text: 'Collections'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(
                  section: _projects,
                  onRetry: () => _loadProjects(force: true),
                  emptyTitle: 'No Projects Found',
                  emptyMessage:
                      'No projects are available for your account on this date.',
                  onSelect: _selectProject,
                  selectedId: _selectedProject?.id,
                  actionLabel: 'View zones',
                ),
                _buildSummaryTab(
                  section: _zones,
                  onRetry: () => _loadZones(force: true),
                  emptyTitle: 'No Zones Found',
                  emptyMessage: _selectedProject == null
                      ? 'No zones are available for your account on this date.'
                      : 'No zones are available for ${_selectedProject!.code}.',
                  onSelect: _selectZone,
                  selectedId: _selectedZone?.id,
                  actionLabel: 'View wards',
                ),
                _buildSummaryTab(
                  section: _wards,
                  onRetry: () => _loadWards(force: true),
                  emptyTitle: 'No Wards Found',
                  emptyMessage: _selectedZone == null
                      ? 'No wards are available for your account on this date.'
                      : 'No wards are available for ${_selectedZone!.code}.',
                  onSelect: _selectWard,
                  selectedId: _selectedWard?.id,
                  actionLabel: 'View collections',
                ),
                _buildCollectionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    final isCollectionsTab = _currentTab == _tabCollections;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap rather than Row so the fields stack instead of overflowing on
          // narrow screens.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: isCollectionsTab
                ? [
                    SizedBox(
                      width: 165,
                      child: DateField(
                        label: 'Start Date',
                        value: _rangeStart,
                        onChanged: _onRangeStartChanged,
                      ),
                    ),
                    SizedBox(
                      width: 165,
                      child: DateField(
                        label: 'End Date',
                        value: _rangeEnd,
                        onChanged: _onRangeEndChanged,
                        firstDate: _rangeStart,
                      ),
                    ),
                  ]
                : [
                    SizedBox(
                      width: 200,
                      child: DateField(
                        label: 'Collection Date',
                        value: _summaryDate,
                        onChanged: _onSummaryDateChanged,
                      ),
                    ),
                  ],
          ),
          if (isCollectionsTab) ...[
            const SizedBox(height: 8),
            Text(
              'Maximum range is ${ApiDate.maxRangeInDays} days.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(),
          ],
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedProject != null || _selectedZone != null || _selectedWard != null;

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Filters:',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        if (_selectedProject != null)
          _FilterChip(
            label: 'Project: ${_selectedProject!.code}',
            onClear: _clearProject,
          ),
        if (_selectedZone != null)
          _FilterChip(
            label: 'Zone: ${_selectedZone!.code}',
            onClear: _clearZone,
          ),
        if (_selectedWard != null)
          _FilterChip(
            label: 'Ward: ${_selectedWard!.code}',
            onClear: _clearWard,
          ),
      ],
    );
  }

  Widget _buildSummaryTab({
    required _Section<CollectionSummary> section,
    required VoidCallback onRetry,
    required String emptyTitle,
    required String emptyMessage,
    required ValueChanged<CollectionSummary> onSelect,
    required int? selectedId,
    required String actionLabel,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      color: AppTheme.accentColor,
      child: SectionStateView(
        isLoading: section.isLoading,
        errorMessage: section.error,
        isSessionError: section.isSessionError,
        isEmpty: section.isEmpty,
        onRetry: section.isSessionError ? _handleSessionExpired : onRetry,
        emptyIcon: Icons.inbox_rounded,
        emptyTitle: emptyTitle,
        emptyMessage: emptyMessage,
        contentBuilder: (context) => ResponsiveCardGrid(
          children: [
            for (final summary in section.items)
              SummaryCard(
                summary: summary,
                isSelected: selectedId == summary.id,
                onTap: () => onSelect(summary),
                actionLabel: actionLabel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      color: AppTheme.accentColor,
      child: SectionStateView(
        isLoading: _collections.isLoading,
        errorMessage: _collections.error,
        isSessionError: _collections.isSessionError,
        isEmpty: _collections.isEmpty,
        onRetry: _collections.isSessionError
            ? _handleSessionExpired
            : () => _loadCollections(force: true),
        emptyIcon: Icons.receipt_long_rounded,
        emptyTitle: 'No Collections Found',
        emptyMessage:
            'No collections were recorded for the selected date range and filters.',
        contentBuilder: (context) => CenteredContent(
          // ListView.builder keeps a long range lazy instead of building every
          // card up front.
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _collections.items.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CollectionCard(collection: _collections.items[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade800,
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 14),
            color: Colors.green.shade800,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            tooltip: 'Clear',
          ),
        ],
      ),
    );
  }
}
