import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin alarmNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> showAlarmNotification() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: androidSettings,
  );

  await alarmNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  await alarmNotificationsPlugin.show(
    id: 999,

    title: 'TODO Reminder',

    body: 'You have a pending task',

    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_channel',

        'TODO Reminders',

        importance: Importance.max,

        priority: Priority.high,
      ),
    ),
  );
}