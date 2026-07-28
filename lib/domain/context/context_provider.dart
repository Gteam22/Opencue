import '../enums/enums.dart';
import '../models/context_snapshot.dart';

/// Supplies a ContextSnapshot describing the current situation.
///
/// This interface exists so that the situation can come from somewhere other
/// than a form without the recommendation engine, the repositories or the
/// results UI changing at all. Anything that can describe a *setting* in the
/// vocabulary of `lib/domain/enums` can implement it.
///
/// Version 1 ships exactly one implementation, ManualContextProvider. No
/// camera, microphone or sensor package is declared anywhere in this project,
/// and no permission is requested. The values below are declared so that a
/// later module has a defined contract to satisfy, not to reserve a feature.
///
/// A future implementation must describe the environment only: how loud a room
/// is, whether a place is a café or a station, whether a dog or an umbrella is
/// present. It must not attempt to decide whether a person is interested,
/// available, or willing to be approached. Those are not observable facts and
/// nothing downstream will treat them as such.
abstract class ContextProvider {
  /// Which source this provider represents.
  ContextSource get source;

  /// Whether the provider can produce a snapshot right now.
  bool get isAvailable;

  /// A short identifier used in the UI and in logs.
  String get id;

  /// Produces the current snapshot.
  ///
  /// Implementations must set `source` on the returned snapshot to [source].
  Future<ContextSnapshot> captureContext();
}

/// The only Version 1 provider: the situation the user typed in.
///
/// It is a thin wrapper rather than a no-op, because it is what pins down the
/// contract for later providers: hand the engine a finished snapshot, tagged
/// with where it came from.
class ManualContextProvider implements ContextProvider {
  ManualContextProvider(this._snapshot);

  /// The snapshot assembled by the situation builder screen.
  final ContextSnapshot _snapshot;

  @override
  ContextSource get source => ContextSource.manual;

  @override
  bool get isAvailable => true;

  @override
  String get id => 'manual';

  @override
  Future<ContextSnapshot> captureContext() async {
    return _snapshot.copyWith(source: ContextSource.manual);
  }
}
