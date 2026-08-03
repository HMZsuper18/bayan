part of 'dashboard_bloc.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {
  const LoadDashboard();
}

class UpdatePrayerTimes extends DashboardEvent {
  final double latitude;
  final double longitude;

  const UpdatePrayerTimes({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

class SearchQueryChanged extends DashboardEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchDashboard extends DashboardEvent {
  final String query;

  const SearchDashboard(this.query);

  @override
  List<Object?> get props => [query];
}

class RefreshDownloadedReciters extends DashboardEvent {
  const RefreshDownloadedReciters();
}