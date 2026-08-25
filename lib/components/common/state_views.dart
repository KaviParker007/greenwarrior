import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_theme.dart';
import 'loading_shimmer.dart';

/// Friendly empty state for a section that loaded but returned nothing.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppTheme.accentColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry affordance.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  /// Session errors get a sign-in prompt rather than a retry label.
  final bool isSessionError;

  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.isSessionError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
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
                isSessionError ? Icons.lock_outline : Icons.wifi_off_rounded,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSessionError ? 'Session Expired' : 'Something Went Wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(isSessionError ? Icons.login : Icons.refresh),
              label: Text(isSessionError ? 'Go to Login' : 'Try Again'),
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
}

/// Renders the loading / error / empty / content states of one section.
///
/// Every D2D tab routes through this so the four states are handled
/// consistently in one place instead of being re-implemented per tab.
class SectionStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isSessionError;
  final bool isEmpty;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  /// Optional call to action shown on the empty state.
  final Widget? emptyAction;
  final WidgetBuilder contentBuilder;

  const SectionStateView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.contentBuilder,
    this.emptyAction,
    this.isSessionError = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingShimmer();
    }
    if (errorMessage != null) {
      return ErrorStateView(
        message: errorMessage!,
        onRetry: onRetry,
        isSessionError: isSessionError,
      );
    }
    if (isEmpty) {
      return EmptyStateView(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        action: emptyAction,
      );
    }
    return contentBuilder(context);
  }
}
