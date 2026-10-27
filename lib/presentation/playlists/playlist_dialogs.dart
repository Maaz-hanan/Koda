import 'package:flutter/material.dart';

import '../../domain/library/playlist_rules.dart';

/// Asks for a playlist name. Returns the trimmed name, or null if cancelled.
/// Shows the problem under the box and stays open until the name is OK.
Future<String?> promptPlaylistName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required List<String> existingNames,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(
      title: title,
      confirmLabel: confirmLabel,
      existingNames: existingNames,
      initial: initial,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    required this.existingNames,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final List<String> existingNames;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validatePlaylistName(_controller.text, widget.existingNames);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Playlist name',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// "Delete playlist?" Returns true only if the user confirms.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete playlist?'),
      content: Text(
        '"$name" will be deleted. The songs in it stay in your library.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
