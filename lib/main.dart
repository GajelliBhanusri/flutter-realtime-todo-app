import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:intl/intl.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
  );

  await notificationsPlugin.initialize(settings: initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'todo_channel',

    'TODO Reminders',

    description: 'Reminder notifications for tasks',

    importance: Importance.max,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await AndroidAlarmManager.initialize();
  tz.initializeTimeZones();

  await initializeNotifications();

  await Permission.notification.request();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: TodoScreen());
  }
}

class TodoScreen extends StatefulWidget {
  @override
  State<TodoScreen> createState() {
    return _TodoScreenState();
  }
}

class _TodoScreenState extends State<TodoScreen> {
  TextEditingController taskController = TextEditingController();
  FocusNode taskFocusNode = FocusNode();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  DateTime? selectedReminderTime;

  Future<void> scheduleNotification(String title, DateTime reminderTime) async {
    Duration delay = reminderTime.difference(DateTime.now());

    if (delay.isNegative) {
      return;
    }

    Future.delayed(delay, () async {
      await notificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,

        title: 'TODO Reminder',

        body: title,

        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_channel',

            'TODO Reminders',

            importance: Importance.max,

            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> addTask() async {
    String task = taskController.text.trim();

    if (task.isEmpty) {
      return;
    }

    Map<String, dynamic> taskData = {
      "title": task,

      "completed": false,

      "createdAt": FieldValue.serverTimestamp(),
    };

    if (selectedReminderTime != null) {
      taskData["reminderTime"] = selectedReminderTime;
    }

    await firestore.collection("tasks").add(taskData);
    if (selectedReminderTime != null) {
      await scheduleNotification(task, selectedReminderTime!);
    }
    taskController.clear();
    setState(() {
      selectedReminderTime = null;
    });

    FocusScope.of(context).requestFocus(taskFocusNode);
  }

  Future<void> deleteTask(String documentId) async {
    await firestore.collection("tasks").doc(documentId).delete();
  }

  Future<void> toggleTask(String documentId, bool currentStatus) async {
    await firestore.collection("tasks").doc(documentId).update({
      "completed": !currentStatus,
    });
  }

  void openReminderBottomSheet() {
    showModalBottomSheet(
      context: context,

      backgroundColor: Colors.white,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),

      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(20),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,

                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              SizedBox(height: 25),

              Text(
                "Set Reminder",

                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 20),

              Wrap(
                spacing: 10,
                runSpacing: 10,

                children: [
                  reminderChip(
                    "Later Today",

                    Icons.wb_sunny_outlined,

                    DateTime.now().add(Duration(hours: 3)),
                  ),

                  reminderChip(
                    "Tonight",

                    Icons.nightlight_round,

                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                      21,
                      0,
                    ),
                  ),

                  reminderChip(
                    "Tomorrow",

                    Icons.calendar_today,

                    DateTime.now().add(Duration(days: 1)),
                  ),

                  reminderChip(
                    "This Weekend",

                    Icons.weekend_outlined,

                    DateTime.now().add(Duration(days: 5)),
                  ),
                ],
              ),

              SizedBox(height: 25),

              SizedBox(
                width: double.infinity,

                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,

                    padding: EdgeInsets.symmetric(vertical: 16),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,

                      initialDate: DateTime.now(),

                      firstDate: DateTime.now(),

                      lastDate: DateTime(2100),
                    );

                    if (pickedDate == null) {
                      return;
                    }

                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,

                      initialTime: TimeOfDay.now(),
                    );

                    if (pickedTime == null) {
                      return;
                    }

                    DateTime finalReminder = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,

                      pickedTime.hour,
                      pickedTime.minute,
                    );

                    setState(() {
                      selectedReminderTime = finalReminder;
                    });

                    Navigator.pop(context);
                  },

                  icon: Icon(Icons.access_time),

                  label: Text("Custom Date & Time"),
                ),
              ),

              SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  Widget reminderChip(String title, IconData icon, DateTime reminderTime) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedReminderTime = reminderTime;
        });

        Navigator.pop(context);
      },

      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),

        decoration: BoxDecoration(
          color: Color(0xFFF4F6FB),

          borderRadius: BorderRadius.circular(16),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(icon, size: 18),

            SizedBox(width: 8),

            Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String formatReminderTime(
    DateTime reminderTime) {

  DateTime now = DateTime.now();

  DateTime today =
      DateTime(now.year, now.month, now.day);

  DateTime tomorrow =
      today.add(Duration(days: 1));

  DateTime reminderDate =
      DateTime(
        reminderTime.year,
        reminderTime.month,
        reminderTime.day,
      );

  String time =
      DateFormat('hh:mm a')
          .format(reminderTime);

  if (reminderDate == today) {
    return "Today • $time";
  }

  if (reminderDate == tomorrow) {
    return "Tomorrow • $time";
  }

  return DateFormat(
    'dd MMM • hh:mm a',
  ).format(reminderTime);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6FB),

      appBar: AppBar(
        elevation: 0,

        backgroundColor: Color(0xFFF4F6FB),

        title: Text(
          "TODO App",

          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),

        centerTitle: true,
      ),

      body: Padding(
        padding: EdgeInsets.all(16),

        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    focusNode: taskFocusNode,
                    textInputAction: TextInputAction.done,

                    onSubmitted: (value) {
                      addTask();
                    },

                    decoration: InputDecoration(
                      hintText: "Enter task",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                SizedBox(width: 10),

                GestureDetector(
                  onTap: openReminderBottomSheet,

                  child: Container(
                    padding: EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),

                    child: Icon(Icons.alarm, color: Colors.black87),
                  ),
                ),

                SizedBox(width: 10),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,

                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  onPressed: addTask,

                  child: Icon(Icons.add),
                ),
              ],
            ),

            SizedBox(height: 20),
            if (selectedReminderTime != null)
              Container(
                margin: EdgeInsets.only(bottom: 15),

                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                decoration: BoxDecoration(
                  color: Colors.orange.shade50,

                  borderRadius: BorderRadius.circular(14),
                ),

                child: Row(
                  children: [
                    Icon(Icons.alarm, color: Colors.orange),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        "Reminder set for: "
                        "${selectedReminderTime.toString()}",

                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedReminderTime = null;
                        });
                      },

                      child: Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: StreamBuilder(
                stream: firestore
                    .collection("tasks")
                    .orderBy("createdAt")
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 90,
                            color: Colors.grey.shade400,
                          ),

                          SizedBox(height: 20),

                          Text(
                            "No Tasks Yet",

                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),

                          SizedBox(height: 10),

                          Text(
                            "Start adding your daily goals",

                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final tasks = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: tasks.length,

                    itemBuilder: (context, index) {
                      final task = tasks[index];

                      final data = task.data() as Map<String, dynamic>;

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),

                        decoration: BoxDecoration(
                          color: data["completed"]
                              ? Colors.green.shade100
                              : Colors.white,

                          borderRadius: BorderRadius.circular(18),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),

                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),

                          leading: GestureDetector(
                            onTap: () {
                              toggleTask(task.id, data["completed"]);
                            },

                            child: Container(
                              width: 24,
                              height: 24,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                color: data["completed"]
                                    ? Colors.green
                                    : Colors.transparent,

                                border: Border.all(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),

                              child: data["completed"]
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),

                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                data["title"],

                                style: TextStyle(
                                  fontSize: 16,

                                  decoration: data["completed"]
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,

                                  color: data["completed"]
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),

                              if (data["reminderTime"] != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 6),

                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.alarm,
                                        size: 16,
                                        color: Colors.orange,
                                      ),

                                      SizedBox(width: 6),

                                      Expanded(
                                        child: Text(
                                          formatReminderTime(
  data["reminderTime"].toDate(),
),

                                          style: TextStyle(
                                            fontSize: 12,

                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          trailing: IconButton(
                            onPressed: () {
                              deleteTask(task.id);
                            },

                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
