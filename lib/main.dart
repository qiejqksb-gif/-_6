import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {data class Booking(
    val id: Int,
    val customerName: String,
    val phone: String,
    val date: String,
    val time: String,
    val notes: String = ""
)

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حجوزات',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }

  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزات'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'بحث في المهام...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(int total, int active, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', TaskFilter.all, total),
          const SizedBox(width: 8),
          _filterChip('نشطة', TaskFilter.active, active),
          const SizedBox(width: 8),
          _filterChip('مكتملة', TaskFilter.completed, completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter, int count) {
    final selected = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visible) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        _deleteTask(task);
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.done
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done
                          ? AppTheme.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task.done
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.done
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(task.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => _deleteTask(task),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث';
      icon = Icons.search_off_rounded;
    } else if (_filter == TaskFilter.completed) {
      message = 'لا توجد مهام مكتملة بعد';
      icon = Icons.check_circle_outline_rounded;
    } else if (_filter == TaskFilter.active) {
      message = 'كل المهام مكتملة!';
      icon = Icons.celebration_rounded;
    } else {
      message = 'ابدأ بإضافة مهمتك الأولى';
      icon = Icons.playlist_add_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
        ‏ndroidx.drawerlayout.widget.DrawerLayout
‏xmlns:android="http://schemas.android.com/apk/res/android"
‏xmlns:app="http://schemas.android.com/apk/res-auto"
‏xmlns:tools="http://schemas.android.com/tools"
‏android:id="@+id/_drawer"
‏android:layout_width="match_parent"
‏android:layout_height="match_parent"
‏tools:openDrawer="start">
‏<androidx.coordinatorlayout.widget.CoordinatorLayout
‏android:id="@+id/_coordinator"
‏android:layout_width="match_parent"
‏android:layout_height="match_parent">
‏<com.google.android.material.appbar.AppBarLayout
‏android:id="@+id/_app_bar"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:theme="@style/AppTheme.AppBarOverlay">
‏<com.google.android.material.appbar.CollapsingToolbarLayout
‏android:id="@+id/collapsingtoolbar1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:fitsSystemWindows="true"
‏app:layout_scrollFlags="scroll|exitUntilCollapsed">
‏<de.hdodenhof.circleimageview.CircleImageView
‏android:id="@+id/circleimageview1"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:src="@drawable/default_image"
‏app:civ_border_width="3dp"
‏app:civ_border_color="#008DCD"
‏app:civ_circle_background_color="#FFFFFF"
‏app:civ_border_overlay="true" />
‏<CheckBox
‏android:id="@+id/checkbox1"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="CheckBox"
‏android:textSize="12sp" />
‏<Button
‏android:id="@+id/button1"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="Button"
‏android:textSize="12sp" />
‏<TextView
‏android:id="@+id/textview5"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="27sp"
‏android:singleLine="true"
‏android:lines="3" />
‏<TextView
‏android:id="@+id/textview6"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="12sp" />
‏<TextView
‏android:id="@+id/textview7"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="12sp" />
‏<TextView
‏android:id="@+id/textview8"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="12sp" />
‏<com.google.android.material.appbar.MaterialToolbar
‏android:id="@+id/_toolbar"
‏android:layout_width="match_parent"
‏android:layout_height="?attr/actionBarSize"
‏android:background="?attr/colorPrimary"
‏app:popupTheme="@style/AppTheme.PopupOverlay" />
‏</com.google.android.material.appbar.CollapsingToolbarLayout>
‏</com.google.android.material.appbar.AppBarLayout>
‏<LinearLayout
‏android:layout_width="match_parent"
‏android:layout_height="match_parent"
‏android:orientation="vertical"
‏app:layout_behavior="@string/appbar_scrolling_view_behavior">
‏<TableLayout
‏android:id="@+id/linear1"
‏android:layout_width="match_parent"
‏android:layout_height="match_parent"
‏android:padding="8dp"
‏android:background="#9C27B0"
‏android:gravity="center_horizontal|center_vertical"
‏android:orientation="vertical"
‏android:weightSum="3"
‏android:layout_gravity="center_horizontal|center_vertical"
‏android:layout_weight="3"
‏android:elevation="اسمالمريض">
‏<HorizontalScrollView
‏android:id="@+id/hscroll1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp">
‏<TextView
‏android:id="@+id/textview1"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="سجل الحجوزات والمواعيد "
‏android:textSize="20sp" />
‏</HorizontalScrollView>
‏<GridView
‏android:id="@+id/gridview1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:numColumns="3"
‏android:stretchMode="columnWidth" />
‏<GridView
‏android:id="@+id/gridview2"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:numColumns="3"
‏android:stretchMode="columnWidth" />
‏<ListView
‏android:id="@+id/listview1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:choiceMode="none" />
‏<GridView
‏android:id="@+id/gridview3"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:numColumns="3"
‏android:stretchMode="columnWidth" />
‏<GridView
‏android:id="@+id/gridview4"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:numColumns="3"
‏android:stretchMode="columnWidth" />
‏<androidx.viewpager.widget.ViewPager
‏android:id="@+id/viewpager1"
‏android:layout_width="match_parent"
‏android:layout_height="match_parent"
‏android:padding="8dp" />
‏<com.google.android.material.tabs.TabLayout
‏android:id="@+id/tablayout1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:background="#008DCD"
‏app:tabGravity="fill"
‏app:tabMode="fixed"
‏app:tabIndicatorHeight="3dp"
‏app:tabIndicatorColor="@android:color/white"
‏app:tabSelectedTextColor="@android:color/white"
‏app:tabTextColor="@android:color/white"
‏app:tabTextAppearance="@android:style/TextAppearance.Widget.TabWidget" />
‏<com.google.android.material.tabs.TabLayout
‏android:id="@+id/tablayout2"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:background="#008DCD"
‏app:tabGravity="fill"
‏app:tabMode="fixed"
‏app:tabIndicatorHeight="3dp"
‏app:tabIndicatorColor="@android:color/white"
‏app:tabSelectedTextColor="@android:color/white"
‏app:tabTextColor="@android:color/white"
‏app:tabTextAppearance="@android:style/TextAppearance.Widget.TabWidget" />
‏<com.google.android.material.tabs.TabLayout
‏android:id="@+id/tablayout3"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:background="#008DCD"
‏app:tabGravity="fill"
‏app:tabMode="fixed"
‏app:tabIndicatorHeight="3dp"
‏app:tabIndicatorColor="@android:color/white"
‏app:tabSelectedTextColor="@android:color/white"
‏app:tabTextColor="@android:color/white"
‏app:tabTextAppearance="@android:style/TextAppearance.Widget.TabWidget" />
‏<com.google.android.material.tabs.TabLayout
‏android:id="@+id/tablayout4"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏android:background="#008DCD"
‏app:tabGravity="fill"
‏app:tabMode="fixed"
‏app:tabIndicatorHeight="3dp"
‏app:tabIndicatorColor="@android:color/white"
‏app:tabSelectedTextColor="@android:color/white"
‏app:tabTextColor="@android:color/white"
‏app:tabTextAppearance="@android:style/TextAppearance.Widget.TabWidget" />
‏<androidx.cardview.widget.CardView
‏android:id="@+id/cardview1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏app:contentPadding="8dp"
‏app:cardElevation="2dp"
‏app:cardCornerRadius="20dp" />
‏<com.google.android.material.textfield.TextInputLayout
‏android:id="@+id/textinputlayout1"
‏android:layout_width="match_parent"
‏android:layout_height="wrap_content"
‏style="@style/Widget.MaterialComponents.TextInputLayout.OutlinedBox" />
‏<androidx.swiperefreshlayout.widget.SwipeRefreshLayout
‏android:id="@+id/swiperefreshlayout1"
‏android:layout_width="match_parent"
‏android:layout_height="match_parent"
‏android:padding="8dp">
‏<TextView
‏android:id="@+id/textview2"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="12sp" />
‏<TextView
‏android:id="@+id/textview3"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="12sp" />
‏<TextView
‏android:id="@+id/textview4"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:padding="8dp"
‏android:text="TextView"
‏android:textSize="12sp" />
‏</androidx.swiperefreshlayout.widget.SwipeRefreshLayout>
‏<ScrollView
‏android:id="@+id/vscroll1"
‏android:layout_width="wrap_content"
‏android:layout_height="match_parent"
‏android:padding="8dp" />
‏<com.google.android.gms.common.SignInButton
‏android:id="@+id/signinbutton1"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content" />
‏</TableLayout>
‏</LinearLayout>
‏<com.google.android.material.floatingactionbutton.FloatingActionButton
‏android:id="@+id/_fab"
‏android:layout_width="wrap_content"
‏android:layout_height="wrap_content"
‏android:layout_margin="16dp"
‏android:layout_gravity="right|bottom" />
‏</androidx.coordinatorlayout.widget.CoordinatorLayout>
‏<LinearLayout
‏android:id="@+id/_nav_view"
‏android:layout_width="320dp"
‏android:layout_height="match_parent"
‏android:layout_gravity="start"
‏android:background="#EEEEEE">
‏<include layout="@layout/_drawer_main" android:id="@+id/drawer" />
‏</LinearLayout>
‏</androidx.drawerlayout.widget.DrawerLayout>
‏    'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
    <!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>نظام الحجوزات والمواعيد</title>

<style>
*{box-sizing:border-box}
body{
 margin:0;
 font-family:Arial,Tahoma,sans-serif;
 background:#f3f4f6;
 color:#111827
}
header{
 background:#111827;
 color:white;
 padding:18px;
 text-align:center
}
nav{
 display:flex;
 gap:6px;
 padding:8px;
 background:white;
 overflow:auto;
 position:sticky;
 top:0;
 z-index:10
}
nav button{
 border:0;
 padding:11px 15px;
 border-radius:10px;
 white-space:nowrap;
 cursor:pointer
}
nav button.active{
 background:#111827;
 color:white
}
main{
 max-width:900px;
 margin:auto;
 padding:15px
}
.page{display:none}
.page.active{display:block}

.cards{
 display:grid;
 grid-template-columns:repeat(3,1fr);
 gap:10px
}
.card{
 background:white;
 padding:18px;
 border-radius:15px;
 box-shadow:0 2px 8px #0001
}
.card b{
 display:block;
 font-size:25px;
 margin-top:8px
}

.box{
 background:white;
 padding:16px;
 border-radius:15px;
 margin-bottom:15px;
 box-shadow:0 2px 8px #0001
}

.grid{
 display:grid;
 grid-template-columns:1fr 1fr;
 gap:10px
}
label{
 display:block;
 font-weight:bold;
 margin-bottom:5px
}
input,select,textarea{
 width:100%;
 padding:12px;
 border:1px solid #ddd;
 border-radius:10px;
 font-size:15px
}
textarea{min-height:90px}

button{
 border:0;
 border-radius:10px;
 padding:11px 15px;
 cursor:pointer
}
.primary{
 background:#111827;
 color:white
}
.danger{
 background:#fee2e2;
 color:#991b1b
}
.success{
 background:#dcfce7;
 color:#166534
}
.actions{
 display:flex;
 gap:8px;
 margin-top:15px;
 flex-wrap:wrap
}

.booking{
 background:white;
 padding:15px;
 margin:10px 0;
 border-radius:15px;
 box-shadow:0 2px 8px #0001
}
.booking-title{
 font-size:18px;
 font-weight:bold
}
.info{
 color:#4b5563;
 line-height:1.9;
 margin:8px 0
}

.search{
 display:grid;
 grid-template-columns:2fr 1fr 1fr;
 gap:8px;
 margin-bottom:12px
}

.empty{
 background:white;
 padding:35px;
 text-align:center;
 border-radius:15px;
 color:#777
}

@media(max-width:600px){
 .cards{grid-template-columns:1fr 1fr}
 .grid{grid-template-columns:1fr}
 .search{grid-template-columns:1fr}
}
</style>
</head>

<body>

<header>
<h2>📅 نظام الحجوزات والمواعيد</h2>
<div id="today"></div>
</header>

<nav>
<button class="active" onclick="showPage('home',this)">الرئيسية</button>
<button onclick="showPage('add',this)">➕ حجز جديد</button>
<button onclick="showPage('bookings',this)">📋 الحجوزات</button>
<button onclick="showPage('employees',this)">👥 الموظفون</button>
<button onclick="showPage('backup',this)">💾 النسخ الاحتياطي</button>
</nav>

<main>

<!-- الرئيسية -->
<section id="home" class="page active">

<div class="cards">
<div class="card">
حجوزات اليوم
<b id="todayCount">0</b>
</div>

<div class="card">
الحجوزات القادمة
<b id="futureCount">0</b>
</div>

<div class="card">
إجمالي الحجوزات
<b id="totalCount">0</b>
</div>
</div>

<div class="box">
<h3>مواعيد اليوم</h3>
<div id="todayList"></div>
</div>

</section>


<!-- إضافة حجز -->
<section id="add" class="page">

<div class="box">

<h3 id="formTitle">إضافة حجز جديد</h3>

<div class="grid">

<div>
<label>اسم الزبون *</label>
<input id="name" placeholder="اسم الزبون">
</div>

<div>
<label>رقم الهاتف</label>
<input id="phone" type="tel" placeholder="07xxxxxxxxx">
</div>

<div>
<label>التاريخ *</label>
<input id="date" type="date">
</div>

<div>
<label>الوقت *</label>
<input id="time" type="time">
</div>

<div>
<label>الخدمة</label>
<input id="service" placeholder="نوع الخدمة">
</div>

<div>
<label>الموظف</label>
<select id="employee"></select>
</div>

<div style="grid-column:1/-1">
<label>ملاحظات</label>
<textarea id="notes"></textarea>
</div>

</div>

<div class="actions">
<button class="primary" onclick="saveBooking()">💾 حفظ الحجز</button>
<button onclick="clearForm()">مسح</button>
</div>

</div>
</section>


<!-- الحجوزات -->
<section id="bookings" class="page">

<div class="search">

<input
id="search"
placeholder="🔎 بحث بالاسم أو الهاتف"
oninput="renderBookings()">

<input
id="filterDate"
type="date"
onchange="renderBookings()">

<select id="filterEmployee"
onchange="renderBookings()">
<option value="">كل الموظفين</option>
</select>

</div>

<div id="bookingList"></div>

</section>


<!-- الموظفون -->
<section id="employees" class="page">

<div class="box">

<h3>إضافة موظف</h3>

<div class="actions">

<input
id="employeeName"
placeholder="اسم الموظف">

<button class="primary" onclick="addEmployee()">
إضافة
</button>

</div>

<hr>

<div id="employeeList"></div>

</di

rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() {
      return request.auth != null;
    }

    function isStaff() {
      return signedIn()
        && exists(
          /databases/$(database)/documents/users/$(request.auth.uid)
        )
        && get(
          /databases/$(database)/documents/users/$(request.auth.uid)
        ).data.active == true
        && get(
          /databases/$(database)/documents/users/$(request.auth.uid)
        ).data.role in ['admin', 'employee'];
    }

    function isAdmin() {
      return isStaff()
        && get(
          /databases/$(database)/documents/users/$(request.auth.uid)
        ).data.role == 'admin';
    }

    match /users/{userId} {
      allow read: if signedIn()
        && (request.auth.uid == userId || isAdmin());

      // لا يستطيع المستخدم منح نفسه صلاحيات.
      // إدارة الحسابات تتم بإجراء إداري آمن.
      allow create, update, delete: if false;
    }

    match /patients/{patientId} {
      allow read, create, update: if isStaff();
      allow delete: if isAdmin();
    }

    match /appointments/{appointmentId} {
      allow read, create, update: if isStaff();
      allow delete: if isAdmin();
    }

    match /payments/{paymentId} {
      allow read: if isStaff();

      // تسجل الدفعات عبر إجراء موثوق يتحقق
      // من المبلغ والمستخدم وسجل التدقيق.
      allow create, update, delete: if false;
    }

    match /auditLogs/{logId} {
      allow read: if isAdmin();
      allow write: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
}