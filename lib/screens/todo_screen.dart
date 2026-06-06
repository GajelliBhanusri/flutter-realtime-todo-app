import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../services/alarm_service.dart';

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
  TextEditingController searchController = TextEditingController();

  String searchText = "";
  String sortOption = "Latest";
  String selectedPriority = "Medium";

  Future<void> scheduleNotification(
    String title,
    DateTime reminderTime,
    int alarmId,
  ) async {
    Duration delay = reminderTime.difference(DateTime.now());

    if (delay.isNegative) {
      return;
    }
    await AndroidAlarmManager.oneShot(
      delay,

      alarmId,

      showAlarmNotification,

      exact: true,

      wakeup: true,
    );
  }

  Future<void> addTask() async {
    String task = taskController.text.trim();

    if (task.isEmpty) {
      return;
    }
    int alarmId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Map<String, dynamic> taskData = {
      "title": task,

      "completed": false,

      "priority": selectedPriority,

      "alarmId": alarmId,

      "createdAt": FieldValue.serverTimestamp(),
    };

    if (selectedReminderTime != null) {
      taskData["reminderTime"] = selectedReminderTime;
    }

    await firestore.collection("tasks").add(taskData);
    if (selectedReminderTime != null) {
      await scheduleNotification(task, selectedReminderTime!, alarmId);
    }
    taskController.clear();
    setState(() {
      selectedReminderTime = null;
      selectedPriority = "Medium";
    });

    FocusScope.of(context).requestFocus(taskFocusNode);
  }

  Future<void> deleteTask(String documentId, int alarmId) async {
    await AndroidAlarmManager.cancel(alarmId);

    await firestore.collection("tasks").doc(documentId).delete();
  }

  Future<void> toggleTask(String documentId, bool currentStatus) async {
    await firestore.collection("tasks").doc(documentId).update({
      "completed": !currentStatus,
    });
  }

  Future<void> editTask(
    String documentId,
    String currentTitle,
    Timestamp? currentReminderTime,
    String currentPriority,
    int alarmId,
  ) async {
    TextEditingController editController = TextEditingController(
      text: currentTitle,
    );
    DateTime? editedReminderTime = currentReminderTime?.toDate();
    String editedPriority = currentPriority;

    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text("Edit Task"),

          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  TextField(
                    controller: editController,
                    decoration: InputDecoration(hintText: "Task title"),
                  ),

                  SizedBox(height: 15),
                  Wrap(
                    spacing: 10,

                    children: [
                      editPriorityChip("High", Colors.red, editedPriority, (
                        value,
                      ) {
                        setDialogState(() {
                          editedPriority = value;
                        });
                      }),

                      editPriorityChip(
                        "Medium",
                        Colors.orange,
                        editedPriority,
                        (value) {
                          setDialogState(() {
                            editedPriority = value;
                          });
                        },
                      ),

                      editPriorityChip("Low", Colors.green, editedPriority, (
                        value,
                      ) {
                        setDialogState(() {
                          editedPriority = value;
                        });
                      }),
                    ],
                  ),

                  if (editedReminderTime != null)
                    Text(
                      "Reminder: ${formatReminderTime(editedReminderTime!)}",
                    ),

                  SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,

                        initialDate: editedReminderTime ?? DateTime.now(),

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

                      setDialogState(() {
                        editedReminderTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,

                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },

                    child: Text("Change Reminder"),
                  ),
                ],
              );
            },
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {
                String updatedTitle = editController.text.trim();

                if (updatedTitle.isNotEmpty) {
                  if (editedReminderTime != null) {
                    await AndroidAlarmManager.cancel(alarmId);

                    await scheduleNotification(
                      updatedTitle,
                      editedReminderTime!,
                      alarmId,
                    );
                  }
                  await firestore.collection("tasks").doc(documentId).update({
                    "title": updatedTitle,

                    "reminderTime": editedReminderTime,
                    "priority": editedPriority,
                  });
                }

                Navigator.pop(context);
              },

              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void openReminderBottomSheet() {
    if (taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enter a task first")));

      return;
    }
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

  Widget priorityChip(String priority, Color color) {
    bool isSelected = selectedPriority == priority;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPriority = priority;
        });
      },

      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: color, width: 2),
        ),

        child: Text(
          priority,

          style: TextStyle(
            color: isSelected ? Colors.white : color,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget editPriorityChip(
    String priority,
    Color color,
    String selectedPriority,
    Function(String) onSelected,
  ) {
    bool isSelected = selectedPriority == priority;

    return GestureDetector(
      onTap: () {
        onSelected(priority);
      },

      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: color),
        ),

        child: Text(
          priority,

          style: TextStyle(
            color: isSelected ? Colors.white : color,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red;

      case "Medium":
        return Colors.orange;

      case "Low":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  String formatReminderTime(DateTime reminderTime) {
    DateTime now = DateTime.now();

    DateTime today = DateTime(now.year, now.month, now.day);

    DateTime tomorrow = today.add(Duration(days: 1));

    DateTime reminderDate = DateTime(
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
    );

    String time = DateFormat('hh:mm a').format(reminderTime);

    if (reminderDate == today) {
      return "Today • $time";
    }

    if (reminderDate == tomorrow) {
      return "Tomorrow • $time";
    }

    return DateFormat('dd MMM • hh:mm a').format(reminderTime);
  }

  void openSortDialog() {
    showModalBottomSheet(
      context: context,

      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            ListTile(
              title: Text("Latest First"),

              onTap: () {
                setState(() {
                  sortOption = "Latest";
                });

                Navigator.pop(context);
              },
            ),

            ListTile(
              title: Text("Oldest First"),

              onTap: () {
                setState(() {
                  sortOption = "Oldest";
                });

                Navigator.pop(context);
              },
            ),

            ListTile(
              title: Text("High Priority First"),

              onTap: () {
                setState(() {
                  sortOption = "High";
                });

                Navigator.pop(context);
              },
            ),

            ListTile(
              title: Text("Low Priority First"),

              onTap: () {
                setState(() {
                  sortOption = "Low";
                });

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
            Container(
              padding: EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),

              child: Column(
                children: [
                  TextField(
                    controller: taskController,
                    textCapitalization: TextCapitalization.sentences,
                    focusNode: taskFocusNode,
                    textInputAction: TextInputAction.done,

                    onSubmitted: (value) {
                      addTask();
                    },

                    decoration: InputDecoration(
                      hintText: "Enter task",

                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),

                  Divider(),

                  SizedBox(height: 4),

                  Wrap(
                    spacing: 10,

                    children: [
                      priorityChip("High", Colors.red),

                      priorityChip("Medium", Colors.orange),

                      priorityChip("Low", Colors.green),
                    ],
                  ),

                  SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,

                    children: [
                      GestureDetector(
                        onTap: openReminderBottomSheet,

                        child: Container(
                          padding: EdgeInsets.all(12),

                          decoration: BoxDecoration(
                            color: Color(0xFFF4F6FB),

                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Icon(
                            Icons.alarm,
                            color: selectedReminderTime != null
                                ? Colors.orange
                                : Colors.black87,
                          ),
                        ),
                      ),

                      SizedBox(width: 10),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        onPressed: addTask,

                        child: Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(16),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),

                    child: TextField(
                      controller: searchController,

                      onChanged: (value) {
                        setState(() {
                          searchText = value.toLowerCase();
                        });
                      },

                      decoration: InputDecoration(
                        hintText: "Search tasks...",
                        contentPadding: EdgeInsets.symmetric(vertical: 16),

                        prefixIcon: Icon(Icons.search),

                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12),

                GestureDetector(
                  onTap: openSortDialog,

                  child: Container(
                    padding: EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(16),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,

                          blurRadius: 4,

                          offset: Offset(0, 2),
                        ),
                      ],
                    ),

                    child: Icon(Icons.sort),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
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

                  final tasks = snapshot.data!.docs.where((task) {
                    final data = task.data() as Map<String, dynamic>;

                    final title = data["title"].toString().toLowerCase();

                    return title.contains(searchText);
                  }).toList();

                  tasks.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;

                    final dataB = b.data() as Map<String, dynamic>;

                    if (sortOption == "Oldest") {
                      final timeA = dataA["createdAt"] as Timestamp?;

                      final timeB = dataB["createdAt"] as Timestamp?;

                      return (timeA ?? Timestamp.now()).compareTo(
                        timeB ?? Timestamp.now(),
                      );
                    }

                    if (sortOption == "High") {
                      Map priorityOrder = {"High": 1, "Medium": 2, "Low": 3};

                      final priorityA = priorityOrder[dataA["priority"]] ?? 2;

                      final priorityB = priorityOrder[dataB["priority"]] ?? 2;

                      return priorityA.compareTo(priorityB);
                    }

                    if (sortOption == "Low") {
                      Map priorityOrder = {"Low": 1, "Medium": 2, "High": 3};

                      final priorityA = priorityOrder[dataA["priority"]] ?? 2;

                      final priorityB = priorityOrder[dataB["priority"]] ?? 2;

                      return priorityA.compareTo(priorityB);
                    }

                    final timeA = dataA["createdAt"] as Timestamp?;

                    final timeB = dataB["createdAt"] as Timestamp?;

                    return (timeB ?? Timestamp.now()).compareTo(
                      timeA ?? Timestamp.now(),
                    );
                  });
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
                          onTap: () {
                            editTask(
                              task.id,
                              data["title"],
                              data["reminderTime"],
                              data["priority"] ?? "Medium",
                              data["alarmId"] ?? 0,
                            );
                          },
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
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,

                                    decoration: BoxDecoration(
                                      color: getPriorityColor(
                                        data["priority"] ?? "Medium",
                                      ),

                                      shape: BoxShape.circle,
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  Expanded(
                                    child: Text(
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
                                  ),
                                ],
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
                              deleteTask(task.id, data["alarmId"] ?? 0);
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
