import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/haptics.dart';
import '../../core/song_title.dart';
import '../../core/storage_paths.dart';
import '../../data/models/song.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/library_provider.dart';
import '../shared/artwork_widget.dart';
import '../theme/app_theme.dart';

/// Opens the iPhone Photos picker and returns the chosen picture's path, or
/// null when the person cancelled. The picture is shrunk to at most
/// 1200 x 1200 so a cover never takes much space.
Future<String?> pickCoverFromPhotos() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 90,
  );
  return file?.path;
}

/// Bottom sheet to rename a song and/or choose a new cover from Photos.
/// The audio file itself is never touched.
class EditSongSheet extends ConsumerStatefulWidget {
  const EditSongSheet({
    super.key,
    required this.song,
    this.pickCover = pickCoverFromPhotos,
  });

  final Song song;

  /// Replaceable in tests (the real picker needs a phone).
  final Future<String?> Function() pickCover;

  static Future<void> show(BuildContext context, Song song) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => EditSongSheet(song: song),
    );
  }

  @override
  ConsumerState<EditSongSheet> createState() => _EditSongSheetState();
}

class _EditSongSheetState extends ConsumerState<EditSongSheet> {
  late final TextEditingController _title;
  String? _pickedPath;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.song.title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Save is allowed when the title is not empty and something changed.
  bool get _canSave {
    if (_saving) return false;
    final clean = cleanSongTitle(_title.text);
    if (clean == null) return false;
    return clean != widget.song.title || _pickedPath != null;
  }

  Future<void> _chooseCover() async {
    Haptics.tick();
    try {
      final path = await widget.pickCover();
      if (path != null && mounted) {
        setState(() {
          _pickedPath = path;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your photos.');
    }
  }

  Future<void> _save() async {
    final clean = cleanSongTitle(_title.text);
    if (clean == null) return;
    // Grab everything we need before the first await.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final library = ref.read(songsProvider.notifier);
    final handler = ref.read(audioHandlerProvider);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await library.editSong(
        widget.song,
        title: clean != widget.song.title ? clean : null,
        coverSourcePath: _pickedPath,
      );
      handler.updateSongInfo(updated);
      Haptics.light();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Song updated.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  Widget _cover() {
    const size = 140.0;
    final picked = _pickedPath;
    if (picked != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.nowPlayingArtwork),
        child: Image.file(
          File(picked),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox(
            width: size,
            height: size,
            child: ColoredBox(
              color: AppColors.glassFill,
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    final art = widget.song.artworkPath == null
        ? null
        : StoragePaths.resolve(widget.song.artworkPath!);
    return ArtworkWidget(
      path: art,
      size: size,
      radius: AppRadius.nowPlayingArtwork,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit song',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Center(child: _cover()),
            const SizedBox(height: 12),
            Align(
              child: FilledButton.tonalIcon(
                key: const Key('edit_song_cover_button'),
                onPressed: _saving ? null : _chooseCover,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Change cover'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('edit_song_title_field'),
              controller: _title,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(kMaxSongTitleLength),
              ],
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) {
                if (_canSave) _save();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    key: const Key('edit_song_cancel_button'),
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('edit_song_save_button'),
                    onPressed: _canSave ? _save : null,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
