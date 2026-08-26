import '../../data/models/reciter_model.dart';
import '../../l10n/app_localizations.dart';

/// Localized display name for a reciter, falling back to the model fields
/// when no translation key exists.
String reciterDisplayName(AppLocalizations l10n, ReciterModel reciter) {
  switch (reciter.id) {
    case 'mishary':
      return l10n.reciterName_mishary;
    case 'sudais':
      return l10n.reciterName_sudais;
    case 'shuraim':
      return l10n.reciterName_shuraim;
    case 'muaiqly':
      return l10n.reciterName_muaiqly;
    case 'dosari':
      return l10n.reciterName_dosari;
    case 'ajmi':
      return l10n.reciterName_ajmi;
    case 'ghamdi':
      return l10n.reciterName_ghamdi;
    case 'huthaify':
      return l10n.reciterName_huthaify;
    case 'abdulbasit':
      return l10n.reciterName_abdulbasit;
    case 'husary':
      return l10n.reciterName_husary;
    case 'minshawi':
      return l10n.reciterName_minshawi;
    case 'banna':
      return l10n.reciterName_banna;
    case 'shatri':
      return l10n.reciterName_shatri;
    case 'rifai':
      return l10n.reciterName_rifai;
    case 'qasim':
      return l10n.reciterName_qasim;
    case 'fares':
      return l10n.reciterName_fares;
    case 'tunaiji':
      return l10n.reciterName_tunaiji;
    default:
      return reciter.arabicName.isNotEmpty ? reciter.arabicName : reciter.name;
  }
}