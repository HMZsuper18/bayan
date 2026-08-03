import 'package:equatable/equatable.dart';
import 'surah_model.dart';

class SearchResults extends Equatable {
  final List<SurahModel> surahs;

  const SearchResults({this.surahs = const []});

  bool get isEmpty => surahs.isEmpty;

  @override
  List<Object?> get props => [surahs];
}

class SearchResultModel extends Equatable {
  final List<SurahModel> surahs;

  const SearchResultModel({this.surahs = const []});

  bool get isEmpty => surahs.isEmpty;

  @override
  List<Object?> get props => [surahs];
}
