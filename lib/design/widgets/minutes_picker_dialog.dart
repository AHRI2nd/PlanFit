import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'app_dialog.dart';

Future<int?> showMinutesPicker(
  BuildContext context, {
  required int initialMinutes,
}) => showAppDialog<int>(
  context: context,
  builder: (_) => _MinutesDialog(initialMinutes),
);

class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog(this.initial);
  final int initial;
  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');
  bool _invalid = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final minutes = int.tryParse(_controller.text);
    if (minutes == null || minutes <= 0) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.durationTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in [15, 30, 60])
                ActionChip(
                  label: Text(l10n.durationMinutes(minutes)),
                  onPressed: () => Navigator.pop(context, minutes),
                ),
            ],
          ),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 5,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.durationTitle,
              errorText: _invalid ? l10n.durationInvalid : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.eventSave)),
      ],
    );
  }
}
