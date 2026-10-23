import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../scripts/data/script_repository.dart';
import '../../scripts/models/script.dart';
import '../../settings/logic/settings_cubit.dart';
import '../../wearables/data/wearables_service.dart';
import '../../wearables/logic/wearables_cubit.dart';
import '../../wearables/models/wearables_models.dart';
import '../logic/presentation_cubit.dart';
import '../models/presentation_settings.dart';
import 'widgets/glasses_cue_view.dart';
import 'widgets/phone_teleprompter.dart';
import 'widgets/presentation_settings_sheet.dart';
import 'widgets/teleprompter_controls.dart';

/// Full-screen presentation. Always uses the dark theme for contrast.
class PresentationScreen extends StatefulWidget {
  const PresentationScreen({super.key, required this.scriptId, this.mode});

  final String scriptId;

  /// Overrides the default mode from settings when provided.
  final PresentationMode? mode;

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  late final Future<Script?> _script = context.read<ScriptRepository>().getById(
    widget.scriptId,
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: FutureBuilder<Script?>(
      future: _script,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingStateView());
        }
        final script = snap.data;
        if (script == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyStateView(
              icon: Icons.find_in_page_outlined,
              title: 'Script not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        final settingsCubit = context.read<SettingsCubit>();
        final repository = context.read<ScriptRepository>();
        final app = settingsCubit.state;
        final defaults = app.presentation;
        return BlocProvider(
          create: (ctx) => PresentationCubit(
            script: script,
            settings: widget.mode == null
                ? defaults
                : defaults.copyWith(mode: widget.mode),
            wearables: ctx.read<WearablesService>(),
            invertBandNavigation: app.invertBandNavigation,
            bandSelectAction: app.bandSelectAction,
            onSettingsChanged: settingsCubit.setPresentation,
            savePosition: repository.savePosition,
            trackSession: settingsCubit.setLastScript,
          ),
          child: const _PresentationView(),
        );
      },
    ),
  );
}

class _PresentationView extends StatefulWidget {
  const _PresentationView();

  @override
  State<_PresentationView> createState() => _PresentationViewState();
}

class _PresentationViewState extends State<_PresentationView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PresentationCubit _cubit = context.read<PresentationCubit>();
  // Created eagerly: a lazy ticker would first be created inside dispose()
  // when the user exits without ever pressing play.
  late final Ticker _ticker;
  late final List<GlobalKey> _cueKeys = List.generate(
    _cubit.state.cues.length,
    (_) => GlobalKey(),
  );
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  Duration _lastTick = Duration.zero;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// Pending or running programmatic scrolls (cue/section jumps, restart).
  /// Auto-scroll and end detection pause meanwhile, so a restart from the
  /// end isn't immediately treated as finished.
  int _navigations = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable().catchError((Object _) {});
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCue(_cubit.state.cueIndex, animate: false),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _ticker.dispose();
    _scroll.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable().catchError((Object _) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pausing also persists the position in case the app is killed.
    if (state != AppLifecycleState.resumed) _cubit.pause();
  }

  // ---- Clock --------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    // Clamp large gaps (e.g. after a jank frame) to avoid jumps.
    final step = dt > const Duration(milliseconds: 100)
        ? const Duration(milliseconds: 100)
        : dt;
    final s = _cubit.state;
    if (!s.isPlaying) return;
    if (s.settings.mode == PresentationMode.glasses) {
      _cubit.tick(step);
      return;
    }
    if (!_scroll.hasClients || _navigations > 0) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 0.5) {
      _cubit.markFinished();
      return;
    }
    final delta = s.settings.scrollPixelsPerSecond * step.inMicroseconds / 1e6;
    _scroll.jumpTo(math.min(pos.maxScrollExtent, pos.pixels + delta));
  }

  void _onStatusChanged(PresentationState s) {
    if (s.isPlaying && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!s.isPlaying && _ticker.isActive) {
      _ticker.stop();
    }
    _scheduleHide();
  }

  // ---- Phone scroll mapping -----------------------------------------------

  Future<void> _scrollToCue(int index, {bool animate = true}) async {
    if (index >= _cueKeys.length) return;
    final ctx = _cueKeys[index].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: PhoneTeleprompter.readingLine,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Motion.curve,
    );
  }

  void _syncFromScroll() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !_scroll.hasClients) return;
    final readingY =
        viewport.localToGlobal(Offset.zero).dy +
        viewport.size.height * PhoneTeleprompter.readingLine +
        4;
    var index = 0;
    for (var i = 0; i < _cueKeys.length; i++) {
      final box = _cueKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox) continue;
      if (box.localToGlobal(Offset.zero).dy <= readingY) {
        index = i;
      } else {
        break;
      }
    }
    final pos = _scroll.position;
    final progress = pos.maxScrollExtent <= 0
        ? 1.0
        : pos.pixels / pos.maxScrollExtent;
    _cubit.syncFromScroll(cueIndex: index, progress: progress);
  }

  // ---- Controls visibility ------------------------------------------------

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_cubit.state.isPlaying) {
      if (!_controlsVisible) setState(() => _controlsVisible = true);
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _cubit.state.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return MultiBlocListener(
      listeners: [
        BlocListener<PresentationCubit, PresentationState>(
          listenWhen: (a, b) => a.status != b.status,
          listener: (_, s) => _onStatusChanged(s),
        ),
        BlocListener<PresentationCubit, PresentationState>(
          listenWhen: (a, b) => a.navigationSeq != b.navigationSeq,
          listener: (_, s) {
            if (s.settings.mode != PresentationMode.phone) return;
            // Counted now, before the ticker's next frame can run.
            _navigations++;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await _scrollToCue(s.cueIndex);
              } finally {
                _navigations--;
              }
            });
          },
        ),
      ],
      child: BlocBuilder<PresentationCubit, PresentationState>(
        builder: (context, s) {
          if (s.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: const EmptyStateView(
                icon: Icons.notes_rounded,
                title: 'Nothing to present',
                message: 'Add some text to this script first.',
              ),
            );
          }
          final phone = s.settings.mode == PresentationMode.phone;
          final showChrome = _controlsVisible || !s.isPlaying;
          return Scaffold(
            backgroundColor: phone ? Palette.ink : c.background,
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                    child: phone
                        ? PhoneTeleprompter(
                            cues: s.cues,
                            currentIndex: s.cueIndex,
                            settings: s.settings,
                            controller: _scroll,
                            cueKeys: _cueKeys,
                            viewportKey: _viewportKey,
                            onScroll: _syncFromScroll,
                          )
                        : _GlassesModeView(cue: _cubit.glassesCueFor(s)),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _GradientProgress(value: s.progress),
                ),
                _Chrome(
                  visible: showChrome,
                  top: _TopBar(state: s),
                  bottom: TeleprompterControls(
                    state: s,
                    onTogglePlay: _cubit.togglePlay,
                    onPreviousCue: _cubit.previousCue,
                    onNextCue: _cubit.nextCue,
                    onPreviousSection: _cubit.previousSection,
                    onNextSection: _cubit.nextSection,
                    onRestart: _cubit.restart,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.top,
    required this.bottom,
  });

  final bool visible;
  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: Motion.medium,
        opacity: visible ? 1 : 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(children: [top, const Spacer(), bottom]),
          ),
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final PresentationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresentationCubit>();
    final glasses = state.settings.mode == PresentationMode.glasses;
    return GlassPanel(
      radius: Radii.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xs,
        vertical: Space.xs,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Exit',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.script.displayTitle,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'CARD ${state.cueIndex + 1} / ${state.cues.length}'
                  '${state.status == PlaybackStatus.finished ? ' · FINISHED' : ''}',
                  style: context.mono(size: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.replay_rounded),
            onPressed: cubit.restart,
          ),
          IconButton(
            tooltip: glasses
                ? 'Switch to phone mode'
                : 'Switch to glasses mode',
            icon: Icon(
              glasses ? Icons.smartphone_rounded : Icons.visibility_outlined,
            ),
            onPressed: () => cubit.updateSettings(
              state.settings.copyWith(
                mode: glasses
                    ? PresentationMode.phone
                    : PresentationMode.glasses,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Display settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              cubit.pause();
              showPresentationSettingsSheet(context, cubit);
            },
          ),
        ],
      ),
    );
  }
}

/// Glasses mode on the phone: the simulator plus honest real-device status.
class _GlassesModeView extends StatelessWidget {
  const _GlassesModeView({required this.cue});

  final GlassesCue? cue;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final wearables = context.watch<WearablesCubit>().state;
    final sending = wearables.canShowCues;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.xl, 96, Space.xl, 140),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Pill(
                  label: sending
                      ? 'Live on ${wearables.deviceName ?? 'glasses'}'
                      : 'Simulator · glasses not connected',
                  icon: sending
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_outlined,
                  color: sending ? c.accentText : c.textMuted,
                  filled: true,
                ),
                const SizedBox(height: Space.xl),
                _LensBezel(child: GlassesCueView(cue: cue)),
                const SizedBox(height: Space.xl),
                Text(
                  sending
                      ? 'Cards update on the glasses as you advance.'
                      : 'This is a preview of the compact glasses layout. '
                            'Connect Meta Ray-Ban Display glasses to show it '
                            'in your view.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
                if (!sending) ...[
                  const SizedBox(height: Space.sm),
                  TextButton(
                    onPressed: () => context.push(Routes.glasses),
                    child: const Text('Glasses setup'),
                  ),
                ],
                if (wearables.inputs == InputsAvailability.denied) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'Neural Band input is not enabled for this app; use the '
                    'on-screen controls.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall!.copyWith(color: c.warning),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin lime → aqua progress line along the top edge.
class _GradientProgress extends StatelessWidget {
  const _GradientProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SizedBox(
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: Motion.medium,
          curve: Motion.curve,
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: c.brandGradient,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(2),
              ),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frames the simulated display like a lens: soft glow, gradient rim.
class _LensBezel extends StatelessWidget {
  const _LensBezel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: 0.35),
            c.borderStrong,
            c.accent2.withValues(alpha: 0.3),
          ],
        ),
        shape: Shapes.of(Radii.lg + 14),
        shadows: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.12),
            blurRadius: 60,
            spreadRadius: 4,
          ),
        ],
      ),
      child: child,
    );
  }
}
