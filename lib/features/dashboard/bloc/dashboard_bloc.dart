import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/search_result_model.dart';
import '../../../data/models/prayer_time_model.dart';
import '../../../data/models/reciter_model.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../core/utils/prayer_time_calculator.dart';
import '../../../services/prayer_times_widget_service.dart';
import '../../../services/reciter_store_service.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final QuranRepository _repository;

  DashboardBloc({required QuranRepository repository})
      : _repository = repository,
        super(const DashboardState()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<UpdatePrayerTimes>(_onUpdatePrayerTimes);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<SearchDashboard>(_onSearchDashboard);
    on<RefreshDownloadedReciters>(_onRefreshDownloadedReciters);
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final reciters = await ReciterStoreService.instance.getDownloadedReciters();
      final prayerTimes = PrayerTimeCalculator.getDefault();
      emit(state.copyWith(
        isLoading: false,
        reciters: reciters,
        prayerTimes: prayerTimes,
        bumpRecitersVersion: true,
      ));
      PrayerTimesWidgetService.update(prayerTimes);
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onUpdatePrayerTimes(
    UpdatePrayerTimes event,
    Emitter<DashboardState> emit,
  ) {
    final times = PrayerTimeCalculator.calculate(
      latitude: event.latitude,
      longitude: event.longitude,
    );
    emit(state.copyWith(prayerTimes: times));
    PrayerTimesWidgetService.update(times);
  }

  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<DashboardState> emit,
  ) {
    emit(state.copyWith(
      searchResults: _repository.search(event.query),
    ));
  }

  void _onSearchDashboard(
    SearchDashboard event,
    Emitter<DashboardState> emit,
  ) {
    final results = _repository.search(event.query);
    emit(state.copyWith(
      searchResult: SearchResultModel(surahs: results.surahs),
    ));
  }

  Future<void> _onRefreshDownloadedReciters(
    RefreshDownloadedReciters event,
    Emitter<DashboardState> emit,
  ) async {
    final reciters = await ReciterStoreService.instance.getDownloadedReciters();
    emit(state.copyWith(
      reciters: reciters,
      bumpRecitersVersion: true,
    ));
  }
}
