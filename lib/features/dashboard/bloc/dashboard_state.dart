part of 'dashboard_bloc.dart';

class DashboardState extends Equatable {
  final bool isLoading;
  final List<ReciterModel> reciters;
  final List<PrayerTimeModel> prayerTimes;
  final SearchResults? searchResults;
  final SearchResultModel searchResult;
  final int _recitersVersion;

  const DashboardState({
    this.isLoading = false,
    this.reciters = const [],
    this.prayerTimes = const [],
    this.searchResults,
    this.searchResult = const SearchResultModel(),
    int recitersVersion = 0,
  }) : _recitersVersion = recitersVersion;

  DashboardState copyWith({
    bool? isLoading,
    List<ReciterModel>? reciters,
    List<PrayerTimeModel>? prayerTimes,
    SearchResults? searchResults,
    SearchResultModel? searchResult,
    bool clearSearch = false,
    bool bumpRecitersVersion = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      reciters: reciters ?? this.reciters,
      prayerTimes: prayerTimes ?? this.prayerTimes,
      searchResults: clearSearch ? null : searchResults ?? this.searchResults,
      searchResult: clearSearch ? const SearchResultModel() : searchResult ?? this.searchResult,
      recitersVersion:
          bumpRecitersVersion ? _recitersVersion + 1 : _recitersVersion,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, _recitersVersion, prayerTimes, searchResults, searchResult];
}