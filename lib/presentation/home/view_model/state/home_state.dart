/// Strava-style tabs: Home, Maps, Record, Groups, You
class HomeState {
  final int currentIndex;

  const HomeState({required this.currentIndex});

  factory HomeState.initial() => const HomeState(currentIndex: 0);

  HomeState copyWith({int? currentIndex}) {
    return HomeState(currentIndex: currentIndex ?? this.currentIndex);
  }
}
