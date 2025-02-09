import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neon/blocs.dart';
import 'package:neon/models.dart';
import 'package:neon_dashboard/src/utils/find.dart';
import 'package:nextcloud/dashboard.dart' as dashboard;
import 'package:rxdart/rxdart.dart';

/// Events for [DashboardBloc].
abstract class DashboardBlocEvents {}

/// States for [DashboardBloc].
abstract class DashboardBlocStates {
  /// Dashboard widgets that are displayed.
  BehaviorSubject<Result<Map<dashboard.Widget, dashboard.WidgetItems?>>> get widgets;
}

/// Implements the business logic for fetching dashboard widgets and their items.
class DashboardBloc extends InteractiveBloc implements DashboardBlocEvents, DashboardBlocStates {
  /// Creates a new Dashboard Bloc instance.
  ///
  /// Automatically starts fetching the widgets and their items and refreshes everything every 30 seconds.
  DashboardBloc(this._account) {
    unawaited(refresh());

    _timer = TimerBloc().registerTimer(const Duration(seconds: 30), refresh);
  }

  final Account _account;
  late final NeonTimer _timer;

  @override
  BehaviorSubject<Result<Map<dashboard.Widget, dashboard.WidgetItems?>>> widgets = BehaviorSubject();

  @override
  void dispose() {
    _timer.cancel();
    unawaited(widgets.close());
    super.dispose();
  }

  @override
  Future<void> refresh() async {
    widgets.add(widgets.valueOrNull?.asLoading() ?? Result.loading());

    try {
      final widgets = <String, dashboard.WidgetItems?>{};
      final v1WidgetIDs = <String>[];
      final v2WidgetIDs = <String>[];

      final response = await _account.client.dashboard.dashboardApi.getWidgets();

      for (final widget in response.body.ocs.data.values) {
        if (widget.itemApiVersions.contains(2)) {
          v2WidgetIDs.add(widget.id);
        } else if (widget.itemApiVersions.contains(1)) {
          v1WidgetIDs.add(widget.id);
        } else {
          debugPrint('Widget supports none of the API versions: ${widget.id}');
        }
      }

      if (v1WidgetIDs.isNotEmpty) {
        debugPrint('Loading v1 widgets: ${v1WidgetIDs.join(', ')}');

        final response = await _account.client.dashboard.dashboardApi.getWidgetItems(widgets: v1WidgetIDs);
        for (final entry in response.body.ocs.data.entries) {
          widgets[entry.key] = dashboard.WidgetItems(
            (final b) => b
              ..items.replace(entry.value)
              ..emptyContentMessage = ''
              ..halfEmptyContentMessage = '',
          );
        }
      }

      if (v2WidgetIDs.isNotEmpty) {
        debugPrint('Loading v2 widgets: ${v2WidgetIDs.join(', ')}');

        final response = await _account.client.dashboard.dashboardApi.getWidgetItemsV2(widgets: v2WidgetIDs);
        widgets.addEntries(response.body.ocs.data.entries);
      }

      this.widgets.add(
            Result.success(
              widgets.map(
                (final id, final items) => MapEntry(
                  response.body.ocs.data.values.find(id),
                  items,
                ),
              ),
            ),
          );
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());

      widgets.add(Result.error(e));
      return;
    }
  }
}
