import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format_duration.dart';
import '../../core/loop_time.dart';
import '../../data/models/loop_profile.dart';
import '../../domain/loop/loop_mode.dart';
import '../../domain/waveform/waveform_peaks.dart';
import '../../providers/audio_handler_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/waveform_provider.dart';
import 'waveform_view.dart';

/// The Custom Loop Editor. [PRD §3.2, FR-014..FR-016, FR-018, FR-024]
///
/// Opened by a long press on the Loop button. Pick Off / Finite / Infinite,
/// a start, an end and a play count; it is SAVED per song. The loop does not
/// move playback: it starts by itself when the song reaches Start.
/// (Phase 4 adds the waveform.)
///
/// Cancel and swipe-down never write anything, so the previous saved loop is
/// untouched. Edits live only in this widget until you press Save.
class LoopEditorSheet extends ConsumerStatefulWidget {
  const LoopEditorSheet({
    super.key,
    required this.songId,
    required this.durationMs,
  });

  final String songId;

  /// Song length in ms, or 0 if unknown.
  final int durationMs;

  static Future<void> show(
    BuildContext context, {
    required String songId,
    required int durationMs,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) =>
          LoopEditorSheet(songId: songId, durationMs: durationMs),
    );
  }

  @override
  ConsumerState<LoopEditorSheet> createState() => _LoopEditorSheetState();
}

class _LoopEditorSheetState extends ConsumerState<LoopEditorSheet> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();

  LoopMode _mode = LoopMode.off;
  int _count = 2;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Waveform (Phase 4-1)
  WaveformPeaks? _peaks;
  double _waveProgress = 0;
  bool _waveLoading = true;
  String? _waveError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWaveform(resetState: false); // fields already start in "loading"
  }

  /// Builds (or reads from cache) the waveform. The form works without it:
  /// if this fails you can still type the times.
  Future<void> _loadWaveform({bool resetState = true}) async {
    if (resetState) {
      setState(() {
        _waveLoading = true;
        _waveError = null;
        _waveProgress = 0;
      });
    }
    try {
      final peaks = await ref.read(waveformLoaderProvider).load(
        widget.songId,
        onProgress: (p) {
          if (mounted) setState(() => _waveProgress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _peaks = peaks;
        _waveLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waveLoading = false;
        _waveError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  /// Pre-fills the form with the saved profile (or sensible defaults).
  Future<void> _load() async {
    LoopProfile profile;
    try {
      profile =
          await ref.read(loopProfileRepositoryProvider).getProfile(widget.songId);
    } catch (_) {
      profile = LoopProfile.defaultFor(widget.songId);
    }
    if (!mounted) return;

    final defaultEnd = widget.durationMs > 0
        ? math.min(widget.durationMs, 30000)
        : 30000;
    setState(() {
      // Whole-song repeat modes are not saved profiles; show those as Off.
      _mode = profile.isSectionMode ? profile.mode : LoopMode.off;
      _startController.text = formatLoopTime(profile.loopStartMs ?? 0);
      _endController.text = formatLoopTime(profile.loopEndMs ?? defaultEnd);
      _count = (profile.finiteCount ?? 2).clamp(1, 99).toInt();
      _loading = false;
    });
  }

  int get _currentPositionMs => ref.read(positionProvider).when(
        data: (p) => p.inMilliseconds,
        loading: () => 0,
        error: (e, s) => 0,
      );

  Future<void> _save() async {
    final start = parseLoopTime(_startController.text);
    final end = parseLoopTime(_endController.text);
    final isSection =
        _mode == LoopMode.finiteSection || _mode == LoopMode.infiniteSection;

    if (isSection && (start == null || end == null)) {
      setState(() => _error = 'Enter times like 1:05 or 65.');
      return;
    }

    final profile = LoopProfile(
      songId: widget.songId,
      mode: _mode,
      loopStartMs: start,
      loopEndMs: end,
      finiteCount: _count,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Same rules as the PRD: start < end, inside the song, count >= 1.
    final problem = profile.validate(durationMs: widget.durationMs);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(loopProfileRepositoryProvider).saveProfile(profile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the loop: $e';
        });
      }
      return;
    }

    // Saved. Now tell the player about it (no silent failures).
    try {
      await ref.read(loopProfileApplierProvider)(profile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Saved, but the loop could not be applied to this song: $e';
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Custom loop',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  if (widget.durationMs > 0) ...[
                    const SizedBox(height: 4),
                    Text('Song length ${formatDurationMs(widget.durationMs)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 16),
                  SegmentedButton<LoopMode>(
                    segments: const [
                      ButtonSegment(value: LoopMode.off, label: Text('Off')),
                      ButtonSegment(
                          value: LoopMode.finiteSection,
                          label: Text('Finite')),
                      ButtonSegment(
                          value: LoopMode.infiniteSection,
                          label: Text('Infinite')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _waveformBlock(scheme),
                  const SizedBox(height: 16),
                  _timeField(
                    fieldKey: const Key('loop_start_field'),
                    controller: _startController,
                    label: 'Start',
                  ),
                  const SizedBox(height: 12),
                  _timeField(
                    fieldKey: const Key('loop_end_field'),
                    controller: _endController,
                    label: 'End',
                  ),
                  if (_mode != LoopMode.off) ...[
                    const SizedBox(height: 8),
                    Text(
                      'The loop starts by itself when the song reaches Start.',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (_mode == LoopMode.finiteSection) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total plays of the section',
                            style: Theme.of(context).textTheme.bodyLarge),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Fewer plays',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _count > 1
                                  ? () => setState(() => _count--)
                                  : null,
                            ),
                            Text('$_count',
                                style: Theme.of(context).textTheme.titleMedium),
                            IconButton(
                              tooltip: 'More plays',
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _count < 99
                                  ? () => setState(() => _count++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('loop_cancel_button'),
                          onPressed:
                              _saving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('loop_save_button'),
                          onPressed: _saving ? null : _save,
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

  /// The waveform with the chosen region highlighted and a moving playhead.
  Widget _waveformBlock(ColorScheme scheme) {
    if (_waveLoading) {
      return SizedBox(
        height: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(value: _waveProgress > 0 ? _waveProgress : null),
            const SizedBox(height: 8),
            Text('Preparing waveform…',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final peaks = _peaks;
    if (peaks == null) {
      return Container(
        key: const Key('waveform_error'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_waveError ?? "No waveform."} You can still type the times.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              key: const Key('waveform_retry'),
              onPressed: _loadWaveform,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Highlight the region only while a section loop is selected and valid.
    final isSection =
        _mode == LoopMode.finiteSection || _mode == LoopMode.infiniteSection;
    final start = isSection ? parseLoopTime(_startController.text) : null;
    final end = isSection ? parseLoopTime(_endController.text) : null;

    return Consumer(
      builder: (context, ref, _) {
        final positionMs = ref.watch(positionProvider).when(
              data: (p) => p.inMilliseconds,
              loading: () => null,
              error: (e, s) => null,
            );
        return WaveformView(
          peaks: peaks,
          totalMs: widget.durationMs,
          startMs: start,
          endMs: end,
          positionMs: positionMs,
        );
      },
    );
  }

  Widget _timeField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'm:ss  (e.g. 1:05)',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton(
            onPressed: () => setState(() {
              controller.text = formatLoopTime(_currentPositionMs);
              _error = null;
            }),
            child: const Text('Use\ncurrent', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}
