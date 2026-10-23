import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/wearables_service.dart';
import '../models/wearables_models.dart';

/// Mirrors the real SDK connection state for the UI.
class WearablesCubit extends Cubit<WearablesState> {
  WearablesCubit(this.service) : super(service.state) {
    _sub = service.states.listen((s) {
      if (!isClosed) emit(s);
    });
  }

  final WearablesService service;
  late final StreamSubscription<WearablesState> _sub;

  Future<void> initialize() => _guard(service.initialize);
  Future<void> register() => _guard(service.register);
  Future<void> unregister() => _guard(service.unregister);
  Future<void> repair() => _guard(service.repair);
  Future<void> connect() => _guard(service.connect);
  Future<void> disconnect() => _guard(service.disconnect);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!isClosed) {
        emit(
          WearablesState(
            status: WearablesStatus.error,
            message: 'Glasses request failed (${e.runtimeType}).',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
