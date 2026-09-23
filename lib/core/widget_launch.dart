/// Launch URI captured in [main] before the first frame so widget-driven
/// actions (play, playbar controls) can run as early as possible instead of
/// waiting for a post-frame channel round-trip.
class WidgetLaunch {
  WidgetLaunch._();

  static Uri? uri;

  /// Consumes the cached launch URI (null when launched normally).
  static Uri? take() {
    final u = uri;
    uri = null;
    return u;
  }
}
