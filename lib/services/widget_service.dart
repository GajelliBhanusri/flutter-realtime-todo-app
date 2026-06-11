import 'package:home_widget/home_widget.dart';

class WidgetService {
  static Future<void> updateWidget(List<String> tasks, int pendingCount) async {
    await HomeWidget.saveWidgetData(
      'tasks',
      tasks.join('\n'),
    );

    await HomeWidget.saveWidgetData(
      'pendingCount',
      pendingCount,
    );

    await HomeWidget.updateWidget(
      name: 'TodoWidgetProvider',
    );
  }
}