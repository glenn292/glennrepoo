import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _taskController = TextEditingController();
  final _descController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  final CollectionReference tasks = FirebaseFirestore.instance.collection(
    'tasks',
  );

  String _currentTime = '';
  String _selectedDate = DateFormat.yMMMMd().format(DateTime.now());
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  void _updateTime() {
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _currentTime = DateFormat.Hms().format(DateTime.now());
      });
      _updateTime();
    });
  }

  Future<void> _pickDeadline() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDeadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _addTask() async {
    final task = _taskController.text.trim();
    final desc = _descController.text.trim();

    if (task.isEmpty || _selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi judul dan pilih deadline')),
      );
      return;
    }

    try {
      await tasks.add({
        'uid': user.uid,
        'task': task,
        'description': desc,
        'done': false,
        'date': DateTime.now(),
        'deadline': _selectedDeadline,
      });

      _taskController.clear();
      _descController.clear();
      setState(() {
        _selectedDeadline = null;
      });
    } catch (e) {
      print('Gagal menambahkan tugas: $e');
    }
  }

  Future<void> _editTask(DocumentSnapshot doc) async {
    final editController = TextEditingController(text: doc['task']);
    final descController = TextEditingController(text: doc['description']);
    DateTime? editDeadline = (doc['deadline'] as Timestamp).toDate();

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Tugas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editController,
                  decoration: const InputDecoration(hintText: 'Judul tugas'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(hintText: 'Deskripsi'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: editDeadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          editDeadline ?? DateTime.now(),
                        ),
                      );
                      if (time != null) {
                        setState(() {
                          editDeadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Edit Deadline'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await doc.reference.update({
                    'task': editController.text,
                    'description': descController.text,
                    'deadline': editDeadline,
                  });
                  Navigator.pop(context);
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
    );
  }

  Future<void> _toggleCheck(DocumentSnapshot doc) async {
    await doc.reference.update({'done': !(doc['done'] as bool)});
  }

  Future<void> _deleteTask(String id) async {
    await tasks.doc(id).delete();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Widget buildTaskTile(DocumentSnapshot doc) {
    final isDone = doc['done'] as bool;
    final deadline = (doc['deadline'] as Timestamp).toDate();
    final description = doc['description'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Checkbox(value: isDone, onChanged: (_) => _toggleCheck(doc)),
        title: Text(
          doc['task'],
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(description, style: const TextStyle(color: Colors.black87)),
            Text(
              'Deadline: ${DateFormat.yMMMd().add_Hm().format(deadline)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editTask(doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteTask(doc.id),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentTime,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _taskController,
              decoration: InputDecoration(
                hintText: 'Judul tugas...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'Deskripsi tugas...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDeadline,
                ),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            if (_selectedDeadline != null)
              Text(
                'Deadline: ${DateFormat.yMMMd().add_Hm().format(_selectedDeadline!)}',
              ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    tasks
                        .where('uid', isEqualTo: user.uid)
                        .orderBy('deadline')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  final today = <DocumentSnapshot>[];
                  final tomorrow = <DocumentSnapshot>[];
                  final upcoming = <DocumentSnapshot>[];

                  final now = DateTime.now();

                  for (var doc in docs) {
                    final deadline = (doc['deadline'] as Timestamp).toDate();
                    if (deadline.day == now.day &&
                        deadline.month == now.month &&
                        deadline.year == now.year) {
                      today.add(doc);
                    } else if (deadline
                            .difference(DateTime(now.year, now.month, now.day))
                            .inDays ==
                        1) {
                      tomorrow.add(doc);
                    } else {
                      upcoming.add(doc);
                    }
                  }

                  Widget buildSection(
                    String title,
                    List<DocumentSnapshot> items,
                  ) {
                    if (items.isEmpty) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...items.map((doc) => buildTaskTile(doc)).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  return ListView(
                    children: [
                      buildSection('Today', today),
                      buildSection('Tomorrow', tomorrow),
                      buildSection('Upcoming', upcoming),
                    ],
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
