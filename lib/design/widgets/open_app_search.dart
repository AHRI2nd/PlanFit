import 'package:flutter/material.dart';
import '../../features/schedule/presentation/search/event_search_screen.dart';
import '../../l10n/app_localizations.dart';
import '../layout/app_layout.dart';

class AppSearchButton extends StatefulWidget {
  const AppSearchButton({super.key});
  @override
  State<AppSearchButton> createState() => _AppSearchButtonState();
}

class _AppSearchButtonState extends State<AppSearchButton> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final anchor = AppLayout.anchorPointOf(context);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DisplayFeatureSubScreen(
            anchorPoint: anchor,
            child: const EventSearchScreen(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppL10n.of(context).searchTooltip,
    onPressed: _opening ? null : _open,
    icon: const Icon(Icons.search),
  );
}
