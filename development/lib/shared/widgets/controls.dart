import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Standard navigation for full-screen flows outside the bottom navigation.
///
/// Many routes are opened with [GoRouter.go], which replaces the current
/// location and therefore may not leave a Navigator history entry. In that
/// case the back affordance uses the caller-provided safe destination instead.
class MarketplaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketplaceAppBar({
    super.key,
    required this.title,
    this.backFallback = '/home',
    this.actions = const [],
  });

  final Widget title;
  final String backFallback;
  final List<Widget> actions;

  void _back(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go(backFallback);
    }
  }

  @override
  Widget build(BuildContext context) => AppBar(
    title: title,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => _back(context),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.home_outlined),
        tooltip: 'Home',
        onPressed: () => context.go('/home'),
      ),
      ...actions,
    ],
  );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Primary submit button that is disabled while the request is in flight.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
  }
}

/// Form/action level error banner. Renders nothing when [message] is null.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message!,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

/// Small status pill for order/application status values.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final String status;

  Color _color(BuildContext context) {
    final s = status.toLowerCase();
    if (s.contains('approve') ||
        s == 'completed' ||
        s == 'received' ||
        s == 'shipped' ||
        s == 'paid') {
      return Colors.green;
    }
    if (s.contains('pending') ||
        s.contains('confirm') ||
        s == 'ready_for_meetup') {
      return Colors.orange;
    }
    if (s.contains('cancel') ||
        s == 'rejected' ||
        s == 'suspended' ||
        s.contains('fail')) {
      return Colors.red;
    }
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: _color(context),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static String statusLabel(String value) => value.isEmpty
      ? value
      : value
            .split('_')
            .map(
              (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
            )
            .join(' ');
}
