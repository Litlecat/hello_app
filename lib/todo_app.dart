import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo App 歡迎頁'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '歡迎使用 TodoList App！',  
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),                                                                                                                                                          
            ElevatedButton(
              onPressed: () {                         
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TodoHomePage(),
                  ),
                );
              },
              child: const Text('開始'),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoListData> _todoLists = [];
  static const String _storageKey = 'todo_lists';
  static const String _timeLabelKey = 'time_label_enabled';
  bool _timeLabelEnabled = false;

  // Google Drive
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );
  GoogleSignInAccount? _googleUser;
  String? _driveFolderId; // 緩存 App 專用資料夾 ID

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((user) {
      setState(() => _googleUser = user);
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google 狀態變更錯誤: $e')));
      }
    });
    _loadTodoLists();
    _loadTimeLabelSetting();
    _silentSignInIfPossible();
  }

  Future<void> _silentSignInIfPossible() async {
    try {
      final user = await _googleSignIn.signInSilently();
      setState(() => _googleUser = user);
    } catch (_) {}
  }

  Future<void> _googleSignInFlow() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user != null) {
        // 確保授予 Drive 檔案權限
        await _googleSignIn.requestScopes(['https://www.googleapis.com/auth/drive.file']);
        setState(() => _googleUser = user);
        if (mounted) {
          // 嘗試關閉可能開著的設定面板，避免按鈕狀態不同步
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google 登入成功')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消登入')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入失敗: $e')));
      }
    }
  }

  Future<void> _googleSignOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    setState(() {
      _googleUser = null;
      _driveFolderId = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已登出 Google')));
    }
  }

  Future<String?> _getAuthToken() async {
    final acc = _googleUser;
    if (acc == null) return null;
    final auth = await acc.authHeaders;
    final bearer = auth['Authorization'];
    if (bearer == null) return null;
    return bearer.replaceFirst('Bearer ', '');
  }

  Future<String?> _ensureDriveFolder(String token) async {
    if (_driveFolderId != null) return _driveFolderId;
    // 搜尋資料夾
    final query = "name = 'TodoListApp' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final res = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(query)}&spaces=drive&fields=files(id,name)'),
      headers: { 'Authorization': 'Bearer $token' },
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>);
      if (files.isNotEmpty) {
        _driveFolderId = (files.first as Map<String, dynamic>)['id'] as String;
        return _driveFolderId;
      }
    }
    // 建立資料夾
    final create = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': 'TodoListApp',
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (create.statusCode == 200) {
      final data = json.decode(create.body) as Map<String, dynamic>;
      _driveFolderId = data['id'] as String;
      return _driveFolderId;
    }
    return null;
  }

  Future<void> _backupToDrive() async {
    final token = await _getAuthToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入 Google')));
      }
      return;
    }
    final folderId = await _ensureDriveFolder(token);
    if (folderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('建立/取得雲端資料夾失敗')));
      }
      return;
    }

    // 準備備份內容（清單 + 日誌 map + 活動紀錄）
    final prefs = await SharedPreferences.getInstance();
    final listsJson = json.encode(_todoLists.map((e) => e.toJson()).toList());
    final logsRaw = prefs.getString('todo_logs_map');
    final activityRaw = prefs.getString('todo_activity_map');
    final backup = json.encode({
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'lists': json.decode(listsJson),
      'logsMap': logsRaw != null ? json.decode(logsRaw) : {},
      'activityMap': activityRaw != null ? json.decode(activityRaw) : {},
    });

    // 先尋找是否已有同名檔案
    final fname = 'todolist_backup.json';
    final q = "name = '${fname}' and '${folderId}' in parents and trashed = false";
    final search = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&spaces=drive&fields=files(id,name)'),
      headers: { 'Authorization': 'Bearer $token' },
    );
    String? fileId;
    if (search.statusCode == 200) {
      final data = json.decode(search.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>);
      if (files.isNotEmpty) {
        fileId = (files.first as Map<String, dynamic>)['id'] as String;
      }
    }

    final metadata = {'name': fname, 'parents': [folderId]};
    final mediaType = 'application/json; charset=UTF-8';

    final uri = fileId == null
        ? Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart')
        : Uri.parse('https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=multipart');

    final boundary = 'boundary${DateTime.now().millisecondsSinceEpoch}';
    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${json.encode(metadata)}\r\n'
        '--$boundary\r\n'
        'Content-Type: $mediaType\r\n\r\n'
        '$backup\r\n'
        '--$boundary--\r\n';

    final upload = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (mounted) {
      if (upload.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('備份成功'))) ;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('備份失敗: ${upload.statusCode}')));
      }
    }
  }

  Future<void> _restoreFromDrive() async {
    final token = await _getAuthToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入 Google')));
      }
      return;
    }
    final folderId = await _ensureDriveFolder(token);
    if (folderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取得雲端資料夾失敗')));
      }
      return;
    }
    final fname = 'todolist_backup.json';
    final q = "name = '${fname}' and '${folderId}' in parents and trashed = false";
    final search = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&spaces=drive&fields=files(id,name)'),
      headers: { 'Authorization': 'Bearer $token' },
    );
    if (search.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到備份檔')));
      }
      return;
    }
    final data = json.decode(search.body) as Map<String, dynamic>;
    final files = (data['files'] as List<dynamic>);
    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('尚未建立備份')));
      }
      return;
    }
    final fileId = (files.first as Map<String, dynamic>)['id'] as String;
    final download = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: { 'Authorization': 'Bearer $token' },
    );
    if (download.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下載失敗: ${download.statusCode}')));
      }
      return;
    }

    final obj = json.decode(download.body) as Map<String, dynamic>;
    final lists = (obj['lists'] as List<dynamic>).map((e) => TodoListData.fromJson(e as Map<String, dynamic>)).toList();
    final logsMap = obj['logsMap'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final activityMap = obj['activityMap'] as Map<String, dynamic>? ?? <String, dynamic>{};

    setState(() {
      _todoLists.clear();
      _todoLists.addAll(lists);
    });
    await _saveTodoLists();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todo_logs_map', json.encode(logsMap));
    await prefs.setString('todo_activity_map', json.encode(activityMap));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('還原完成')));
    }
  }

  Future<void> _loadTimeLabelSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _timeLabelEnabled = prefs.getBool(_timeLabelKey) ?? false;
    });
  }

  Future<void> _saveTimeLabelSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeLabelKey, _timeLabelEnabled);
  }

  Future<void> _loadTodoLists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      final List<dynamic> jsonData = json.decode(jsonStr);
      setState(() {
        _todoLists.clear();
        _todoLists.addAll(jsonData.map((e) => TodoListData.fromJson(e)));
      });
    }
  }

  Future<void> _saveTodoLists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(_todoLists.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  void _addTodoList(TodoListData data) {
    setState(() {
      _todoLists.add(data);
    });
    _saveTodoLists();
  }

  void _updateTodoList(int index, TodoListData newData) {
    setState(() {
      _todoLists[index] = newData;
    });
    _saveTodoLists();
  }

  void _deleteTodoList(int index) {
    setState(() {
      _todoLists.removeAt(index);
    });
    _saveTodoLists();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('啟用時間標籤 (HH:mm)', style: TextStyle(fontSize: 16)),
                      Switch(
                        value: _timeLabelEnabled,
                        onChanged: (v) {
                          setModalState(() => _timeLabelEnabled = v);
                          setState(() {});
                          _saveTimeLabelSetting();
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _googleUser == null ? _googleSignInFlow : null,
                          icon: const Icon(Icons.login),
                          label: const Text('登入 Google'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _googleUser != null ? _googleSignOut : null,
                          icon: const Icon(Icons.logout),
                          label: const Text('登出'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _googleUser != null ? _backupToDrive : null,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('備份到雲端'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _googleUser != null ? _restoreFromDrive : null,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('從雲端還原'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _googleUser != null ? _uploadActivityCsvToDrive : null,
                      icon: const Icon(Icons.table_chart),
                      label: const Text('上傳活動CSV到雲端'),
                    ),
                  ),
                  if (_googleUser != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('已登入：${_googleUser!.email}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadActivityCsvToDrive() async {
    final token = await _getAuthToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入 Google')));
      }
      return;
    }
    final folderId = await _ensureDriveFolder(token);
    if (folderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('建立/取得雲端資料夾失敗')));
      }
      return;
    }

    // 讀取全部活動紀錄並轉為 CSV
    final prefs = await SharedPreferences.getInstance();
    final rawEvt = prefs.getString('todo_activity_map');
    final List<ActivityEvent> all = [];
    if (rawEvt != null) {
      final Map<String, dynamic> byDate = json.decode(rawEvt) as Map<String, dynamic>;
      byDate.forEach((date, listRaw) {
        for (final e in (listRaw as List<dynamic>)) {
          all.add(ActivityEvent.fromJson(e as Map<String, dynamic>));
        }
      });
    }
    all.sort((a, b) => a.timeIso.compareTo(b.timeIso));

    final buffer = StringBuffer();
    buffer.writeln('date,time,list,item,subitem,action');
    for (final e in all) {
      final dt = DateTime.parse(e.timeIso);
      final date = _formatYMD(dt);
      final time = _formatHHmm(dt);
      final list = e.listTitle.replaceAll(',', '，');
      final item = e.itemTitle.replaceAll(',', '，');
      final sub = (e.subTitle ?? '').replaceAll(',', '，');
      buffer.writeln('$date,$time,$list,$item,$sub,${e.action}');
    }

    final fname = 'todolist_activity.csv';
    final q = "name = '${fname}' and '${folderId}' in parents and trashed = false";
    final search = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&spaces=drive&fields=files(id,name)'),
      headers: { 'Authorization': 'Bearer $token' },
    );
    String? fileId;
    if (search.statusCode == 200) {
      final data = json.decode(search.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>);
      if (files.isNotEmpty) {
        fileId = (files.first as Map<String, dynamic>)['id'] as String;
      }
    }

    final metadata = {'name': fname, 'parents': [folderId]};
    final mediaType = 'text/csv; charset=UTF-8';

    final uri = fileId == null
        ? Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart')
        : Uri.parse('https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=multipart');

    final boundary = 'boundary${DateTime.now().millisecondsSinceEpoch}';
    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${json.encode(metadata)}\r\n'
        '--$boundary\r\n'
        'Content-Type: $mediaType\r\n\r\n'
        '${buffer.toString()}\r\n'
        '--$boundary--\r\n';

    final upload = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (mounted) {
      if (upload.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('活動CSV上傳成功')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上傳失敗: ${upload.statusCode}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的待辦清單'),
        leading: IconButton(
          icon: const Icon(Icons.add),
          tooltip: '新增清單',
          onPressed: () async {
            final result = await Navigator.of(context).push<TodoListData>(
              MaterialPageRoute(
                builder: (context) => const AddTodoPage(),
              ),
            );
            if (result != null) {
              _addTodoList(result);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今日',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TodayPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: '統計',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StatsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _todoLists.isEmpty
          ? const Center(
              child: Text(
                '這裡將顯示 Todo 清單',
                style: TextStyle(fontSize: 24),
              ),
            )
          : ListView.builder(
              itemCount: _todoLists.length,
              itemBuilder: (context, listIndex) {
                final list = _todoLists[listIndex];
                return GestureDetector(
                  onTap: () async {
                    final updated = await Navigator.of(context).push<TodoListData>(
                      MaterialPageRoute(
                        builder: (context) => TodoDetailPage(
                          data: list,
                          timeLabelEnabled: _timeLabelEnabled,
                        ),
                      ),
                    );
                    if (updated != null) {
                      _updateTodoList(listIndex, updated);
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(list.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final result = await Navigator.of(context).push<TodoListData>(
                                      MaterialPageRoute(
                                        builder: (context) => AddTodoPage(
                                          initialData: list,
                                        ),
                                      ),
                                    );
                                    if (result != null) {
                                      _updateTodoList(listIndex, result);
                                    }
                                  } else if (value == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('確認刪除'),
                                        content: const Text('確定要刪除此清單嗎？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('刪除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      _deleteTodoList(listIndex);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('編輯'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('刪除'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...list.items.asMap().entries.map((entry) {
                            final item = entry.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('・${item.title}', style: const TextStyle(fontSize: 16)),
                                if (item.subItems.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16, top: 2),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: item.subItems.map((sub) => Text('- ${sub.title}', style: const TextStyle(fontSize: 14, color: Colors.grey))).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

String _formatHHmm(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}';
}

String _formatYMD(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

class ActivityEvent {
  final String timeIso; // 勾選時間
  final String listTitle;
  final String itemTitle;
  final String? subTitle; // 若為細項
  final String action; // 'check' 或 'uncheck'
  ActivityEvent({required this.timeIso, required this.listTitle, required this.itemTitle, this.subTitle, required this.action});
  Map<String, dynamic> toJson() => {
        'time': timeIso,
        'listTitle': listTitle,
        'itemTitle': itemTitle,
        'subTitle': subTitle,
        'action': action,
      };
  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        timeIso: json['time'] as String,
        listTitle: json['listTitle'] as String,
        itemTitle: json['itemTitle'] as String,
        subTitle: json['subTitle'] as String?,
        action: json['action'] as String,
      );
}

class TodayLogSubItem {
  final String title;
  final String? completedAtIso;
  TodayLogSubItem({required this.title, required this.completedAtIso});
  Map<String, dynamic> toJson() => {
        'title': title,
        'completedAt': completedAtIso,
      };
  factory TodayLogSubItem.fromJson(Map<String, dynamic> json) => TodayLogSubItem(
        title: json['title'] as String,
        completedAtIso: json['completedAt'] as String?,
      );
}

class TodayLogItem {
  final String title;
  final String? completedAtIso;
  final List<TodayLogSubItem> subItems;
  TodayLogItem({required this.title, required this.completedAtIso, required this.subItems});
  Map<String, dynamic> toJson() => {
        'title': title,
        'completedAt': completedAtIso,
        'subItems': subItems.map((e) => e.toJson()).toList(),
      };
  factory TodayLogItem.fromJson(Map<String, dynamic> json) => TodayLogItem(
        title: json['title'] as String,
        completedAtIso: json['completedAt'] as String?,
        subItems: (json['subItems'] as List<dynamic>? ?? [])
            .map((e) => TodayLogSubItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TodayLog {
  final String dateYMD; // yyyy-MM-dd
  final String listTitle;
  final List<TodayLogItem> items;
  TodayLog({required this.dateYMD, required this.listTitle, required this.items});
  Map<String, dynamic> toJson() => {
        'date': dateYMD,
        'listTitle': listTitle,
        'items': items.map((e) => e.toJson()).toList(),
      };
  factory TodayLog.fromJson(Map<String, dynamic> json) => TodayLog(
        dateYMD: json['date'] as String,
        listTitle: json['listTitle'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => TodayLogItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TodoListData {
  final String title;
  final List<TodoItemData> items;
  TodoListData({required this.title, required List<_TodoItemData> items})
      : items = items.map((e) => TodoItemData.copy(e)).toList();
  TodoListData.json({required this.title, required this.items});

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
  factory TodoListData.fromJson(Map<String, dynamic> json) => TodoListData.json(
        title: json['title'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => TodoItemData.fromJson(e))
            .toList(),
      );
}

class TodoSubItemData {
  final String title;
  final bool completed;
  final String? completedAtIso; // ISO-8601 字串
  const TodoSubItemData({required this.title, required this.completed, this.completedAtIso});
  Map<String, dynamic> toJson() => {
        'title': title,
        'completed': completed,
        'completedAt': completedAtIso,
      };
  factory TodoSubItemData.fromJson(dynamic json) {
    if (json is String) {
      return TodoSubItemData(title: json, completed: false, completedAtIso: null);
    }
    final map = json as Map<String, dynamic>;
    return TodoSubItemData(
      title: map['title'] as String,
      completed: (map['completed'] as bool?) ?? false,
      completedAtIso: map['completedAt'] as String?,
    );
  }
  DateTime? get completedAt => completedAtIso != null ? DateTime.tryParse(completedAtIso!) : null;
}

class TodoItemData {
  final String title;
  final bool completed;
  final String? completedAtIso; // ISO-8601 字串
  final List<TodoSubItemData> subItems;
  const TodoItemData({required this.title, required this.completed, this.completedAtIso, required this.subItems});
  factory TodoItemData.copy(_TodoItemData data) => TodoItemData(
        title: data.controller.text.trim(),
        completed: false,
        completedAtIso: null,
        subItems: data.subControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => TodoSubItemData(title: s, completed: false, completedAtIso: null))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
        'title': title,
        'completed': completed,
        'completedAt': completedAtIso,
        'subItems': subItems.map((e) => e.toJson()).toList(),
      };
  factory TodoItemData.fromJson(Map<String, dynamic> json) => TodoItemData(
        title: json['title'] as String,
        completed: (json['completed'] as bool?) ?? false,
        completedAtIso: json['completedAt'] as String?,
        subItems: (json['subItems'] as List<dynamic>?)
                ?.map((e) => TodoSubItemData.fromJson(e))
                .toList() ??
            const <TodoSubItemData>[],
      );
  DateTime? get completedAt => completedAtIso != null ? DateTime.tryParse(completedAtIso!) : null;
}

class TodoDetailPage extends StatefulWidget {
  final TodoListData data;
  final bool timeLabelEnabled;
  const TodoDetailPage({super.key, required this.data, required this.timeLabelEnabled});

  @override
  State<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoCheckItem {
  bool checked;
  final String title;
  String? completedAtIso;
  final List<_TodoCheckSubItem> subItems;
  _TodoCheckItem({required this.title, required this.checked, this.completedAtIso, required this.subItems});
}
class _TodoCheckSubItem {
  bool checked;
  final String title;
  String? completedAtIso;
  _TodoCheckSubItem({required this.title, required this.checked, this.completedAtIso});
}

class _TodoDetailPageState extends State<TodoDetailPage> {
  late List<_TodoCheckItem> _items;
  List<ActivityEvent> _todayEvents = [];

  @override
  void initState() {
    super.initState();
    _items = widget.data.items.map((item) => _TodoCheckItem(
      title: item.title,
      checked: item.completed,
      completedAtIso: item.completedAtIso,
      subItems: item.subItems.map((s) => _TodoCheckSubItem(title: s.title, checked: s.completed, completedAtIso: s.completedAtIso)).toList(),
    )).toList();
    _loadTodayEventsForList();
  }

  Future<void> _loadTodayEventsForList() async {
    final prefs = await SharedPreferences.getInstance();
    final date = _formatYMD(DateTime.now());
    final raw = prefs.getString('todo_activity_map');
    if (raw == null) {
      setState(() => _todayEvents = []);
      return;
    }
    final Map<String, dynamic> byDate = json.decode(raw) as Map<String, dynamic>;
    final List<dynamic> listRaw = (byDate[date] as List<dynamic>?) ?? <dynamic>[];
    final listEvents = listRaw
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .where((e) => e.listTitle == widget.data.title)
        .toList();
    listEvents.sort((a, b) => a.timeIso.compareTo(b.timeIso));
    setState(() => _todayEvents = listEvents);
  }

  void _toggleMajor(int idx, bool? value) {
    setState(() {
      final v = value ?? false;
      _items[idx].checked = v;
      final nowIso = widget.timeLabelEnabled && v ? DateTime.now().toIso8601String() : null;
      _items[idx].completedAtIso = nowIso;
      for (final sub in _items[idx].subItems) {
        sub.checked = v;
        sub.completedAtIso = nowIso;
      }
    });
    // 取消即時活動記錄，改於儲存時統一記錄
  }

  void _toggleSub(int idx, int subIdx, bool? value) {
    setState(() {
      final v = value ?? false;
      final sub = _items[idx].subItems[subIdx];
      sub.checked = v;
      sub.completedAtIso = widget.timeLabelEnabled && v ? DateTime.now().toIso8601String() : null;
      final allChecked = _items[idx].subItems.isNotEmpty && _items[idx].subItems.every((s) => s.checked);
      _items[idx].checked = allChecked;
      _items[idx].completedAtIso = widget.timeLabelEnabled && allChecked ? DateTime.now().toIso8601String() : (allChecked ? _items[idx].completedAtIso : null);
      if (!allChecked) {
        _items[idx].completedAtIso = null;
      }
    });
    // 取消即時活動記錄，改於儲存時統一記錄
  }

  Future<void> _logActivity({required String itemTitle, String? subTitle, required String action}) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _formatYMD(DateTime.now());
    final key = 'todo_activity_map';
    final raw = prefs.getString(key);
    final Map<String, dynamic> map = raw != null ? (json.decode(raw) as Map<String, dynamic>) : <String, dynamic>{};
    final List<dynamic> list = (map[date] as List<dynamic>?) ?? <dynamic>[];
    final evt = ActivityEvent(
      timeIso: DateTime.now().toIso8601String(),
      listTitle: widget.data.title,
      itemTitle: itemTitle,
      subTitle: subTitle,
      action: action,
    );
    list.add(evt.toJson());
    map[date] = list;
    await prefs.setString(key, json.encode(map));
  }

  Future<void> _logDeltaActivities(TodoListData before, TodoListData after) async {
    // 建立查找表（以標題匹配）
    final Map<String, TodoItemData> beforeItems = { for (final i in before.items) i.title: i };
    final Map<String, TodoItemData> afterItems  = { for (final i in after.items)  i.title: i };

    for (final entry in afterItems.entries) {
      final title = entry.key;
      final aItem = entry.value;
      final bItem = beforeItems[title];
      if (bItem != null) {
        if (aItem.completed != bItem.completed) {
          await _logActivity(itemTitle: title, action: aItem.completed ? 'check' : 'uncheck');
        }
        // 細項比較
        final Map<String, TodoSubItemData> bSubs = { for (final s in bItem.subItems) s.title: s };
        for (final s in aItem.subItems) {
          final bs = bSubs[s.title];
          if (bs != null && bs.completed != s.completed) {
            await _logActivity(itemTitle: title, subTitle: s.title, action: s.completed ? 'check' : 'uncheck');
          }
        }
      } else {
        // 新增的大項：對於完成中的視為本次勾選
        if (aItem.completed) {
          await _logActivity(itemTitle: title, action: 'check');
        }
        for (final s in aItem.subItems) {
          if (s.completed) {
            await _logActivity(itemTitle: title, subTitle: s.title, action: 'check');
          }
        }
      }
    }
  }

  void _onSave() async {
    // 將目前勾選狀態存回清單資料
    final updated = TodoListData.json(
      title: widget.data.title,
      items: _items.map((i) => TodoItemData(
        title: i.title,
        completed: i.checked,
        completedAtIso: i.completedAtIso,
        subItems: i.subItems.map((s) => TodoSubItemData(title: s.title, completed: s.checked, completedAtIso: s.completedAtIso)).toList(),
      )).toList(),
    );

    // 寫入今日日誌（依清單標題覆蓋/更新）
    final prefs = await SharedPreferences.getInstance();
    final String date = _formatYMD(DateTime.now());
    final String logKey = 'todo_logs_map';
    final raw = prefs.getString(logKey);
    Map<String, dynamic> byDate = raw != null ? (json.decode(raw) as Map<String, dynamic>) : <String, dynamic>{};
    final List<dynamic> existingForDate = (byDate[date] as List<dynamic>?) ?? <dynamic>[];

    final newLog = TodayLog(
      dateYMD: date,
      listTitle: updated.title,
      items: updated.items.map((it) => TodayLogItem(
        title: it.title,
        completedAtIso: it.completedAtIso,
        subItems: it.subItems.map((sub) => TodayLogSubItem(title: sub.title, completedAtIso: sub.completedAtIso)).toList(),
      )).toList(),
    );

    final List<TodayLog> todayLogs = existingForDate
        .map((e) => TodayLog.fromJson(e as Map<String, dynamic>))
        .toList();
    final idx = todayLogs.indexWhere((e) => e.listTitle == newLog.listTitle);
    if (idx >= 0) {
      todayLogs[idx] = newLog;
    } else {
      todayLogs.add(newLog);
    }
    byDate[date] = todayLogs.map((e) => e.toJson()).toList();
    await prefs.setString(logKey, json.encode(byDate));

    // 儲存時才記錄活動：比對前後差異
    await _logDeltaActivities(widget.data, updated);

    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _onSave,
            tooltip: '儲存並返回',
          ),
        ],
      ),
      body: ListView(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (context, idx) {
              final item = _items[idx];
              final itemTime = (widget.timeLabelEnabled && item.completedAtIso != null)
                  ? _formatHHmm(DateTime.parse(item.completedAtIso!))
                  : null;
              return Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: item.checked,
                            onChanged: (v) => _toggleMajor(idx, v),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 18))),
                                if (itemTime != null)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(itemTime, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (item.subItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Column(
                            children: item.subItems.asMap().entries.map((entry) {
                              final sub = entry.value;
                              final subTime = (widget.timeLabelEnabled && sub.completedAtIso != null)
                                  ? _formatHHmm(DateTime.parse(sub.completedAtIso!))
                                  : null;
                              return Row(
                                children: [
                                  Checkbox(
                                    value: sub.checked,
                                    onChanged: (v) => _toggleSub(idx, entry.key, v),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(sub.title, style: const TextStyle(fontSize: 16, color: Colors.grey))),
                                        if (subTime != null)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(subTime, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Text('今日活動', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (_todayEvents.isEmpty)
            const ListTile(title: Text('今天尚無活動'))
          else ..._todayEvents.map((e) {
            final t = _formatHHmm(DateTime.parse(e.timeIso));
            final target = e.subTitle != null ? '${e.itemTitle} / ${e.subTitle}' : e.itemTitle;
            final action = e.action == 'check' ? '勾選' : '取消';
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text('$t - $action'),
              subtitle: Text(target),
              dense: true,
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<TodayLog> _logs = [];
  List<ActivityEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final String date = _formatYMD(DateTime.now());
    final raw = prefs.getString('todo_logs_map');
    if (raw == null) {
      setState(() => _logs = []);
    } else {
      final Map<String, dynamic> byDate = json.decode(raw) as Map<String, dynamic>;
      final List<dynamic> listRaw = (byDate[date] as List<dynamic>?) ?? <dynamic>[];
      _logs = listRaw.map((e) => TodayLog.fromJson(e as Map<String, dynamic>)).toList();
    }
    final rawEvt = prefs.getString('todo_activity_map');
    if (rawEvt != null) {
      final Map<String, dynamic> byDate = json.decode(rawEvt) as Map<String, dynamic>;
      final List<dynamic> listRaw = (byDate[date] as List<dynamic>?) ?? <dynamic>[];
      _events = listRaw.map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>)).toList();
      _events.sort((a, b) => a.timeIso.compareTo(b.timeIso));
    } else {
      _events = [];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日紀錄'),
      ),
      body: ListView(
        children: [
          if (_logs.isEmpty)
            const ListTile(title: Text('今天尚無總覽紀錄'))
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text('清單總覽', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ..._logs.map((log) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.listTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...log.items.map((it) {
                          final t = it.completedAtIso != null ? _formatHHmm(DateTime.parse(it.completedAtIso!)) : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('・${it.title}', style: const TextStyle(fontSize: 16))),
                                    if (t != null)
                                      Text(t, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  ],
                                ),
                                if (it.subItems.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16, top: 2),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: it.subItems.map((s) {
                                        final st = s.completedAtIso != null ? _formatHHmm(DateTime.parse(s.completedAtIso!)) : null;
                                        return Row(
                                          children: [
                                            Expanded(child: Text('- ${s.title}', style: const TextStyle(fontSize: 14, color: Colors.grey))),
                                            if (st != null)
                                              Text(st, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                )),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
            child: Text('活動時間軸', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (_events.isEmpty)
            const ListTile(title: Text('今天尚無活動'))
          else ..._events.map((e) {
            final t = _formatHHmm(DateTime.parse(e.timeIso));
            final target = e.subTitle != null ? '${e.itemTitle} / ${e.subTitle}' : e.itemTitle;
            final action = e.action == 'check' ? '勾選' : '取消';
            return ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('$t - $action：${e.listTitle}'),
              subtitle: Text(target),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<TodayLog> _allLogs = [];
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadAll();
  }

  DateTime _toYMD(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('todo_logs_map');
    if (raw == null) {
      setState(() => _allLogs = []);
      return;
    }
    final Map<String, dynamic> byDate = json.decode(raw) as Map<String, dynamic>;
    final List<TodayLog> logs = [];
    byDate.forEach((k, v) {
      final list = (v as List<dynamic>).map((e) => TodayLog.fromJson(e as Map<String, dynamic>)).toList();
      logs.addAll(list);
    });
    setState(() => _allLogs = logs);
  }

  int _countDoneInRange(String listTitle, DateTime start, DateTime endInclusive) {
    final startStr = _formatYMD(start);
    final endStr = _formatYMD(endInclusive);
    // 以日期字串比較時需要解析日誌
    final rangeSet = <String>{};
    DateTime cur = _toYMD(start);
    while (!cur.isAfter(endInclusive)) {
      rangeSet.add(_formatYMD(cur));
      cur = cur.add(const Duration(days: 1));
    }
    int count = 0;
    // 若任一大項或其細項有完成時間則視為當日該清單完成一次
    final Map<String, List<TodayLog>> logsByDate = {};
    for (final log in _allLogs) {
      logsByDate.putIfAbsent(log.dateYMD, () => []).add(log);
    }
    for (final date in rangeSet) {
      final logs = logsByDate[date] ?? const <TodayLog>[];
      final forList = logs.where((l) => l.listTitle == listTitle);
      final anyDone = forList.any((l) => l.items.any((it) =>
          it.completedAtIso != null || it.subItems.any((s) => s.completedAtIso != null)));
      if (anyDone) count++;
    }
    return count;
  }

  int _calcStreak(String listTitle) {
    // 從今天往前連續天數，若某天無完成則中斷
    final Map<String, List<TodayLog>> logsByDate = {};
    for (final log in _allLogs) {
      logsByDate.putIfAbsent(log.dateYMD, () => []).add(log);
    }
    int streak = 0;
    DateTime cur = _toYMD(_today);
    while (true) {
      final dateStr = _formatYMD(cur);
      final logs = logsByDate[dateStr] ?? const <TodayLog>[];
      final anyDone = logs.any((l) => l.listTitle == listTitle && l.items.any((it) =>
          it.completedAtIso != null || it.subItems.any((s) => s.completedAtIso != null)));
      if (anyDone) {
        streak++;
        cur = cur.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    // 彙整所有清單名稱
    final titles = _allLogs.map((e) => e.listTitle).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
      ),
      body: titles.isEmpty
          ? const Center(child: Text('尚無統計資料'))
          : ListView.builder(
              itemCount: titles.length,
              itemBuilder: (context, i) {
                final title = titles[i];
                final last7 = _countDoneInRange(title, _today.subtract(const Duration(days: 6)), _today);
                final last30 = _countDoneInRange(title, _today.subtract(const Duration(days: 29)), _today);
                final streak = _calcStreak(title);
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('最近7天：$last7 天'),
                            Text('最近30天：$last30 天'),
                            Text('連續：$streak 天'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AddTodoPage extends StatefulWidget {
  final TodoListData? initialData;
  const AddTodoPage({super.key, this.initialData});

  @override
  State<AddTodoPage> createState() => _AddTodoPageState();
}

class _AddTodoPageState extends State<AddTodoPage> {
  late TextEditingController _titleController;
  late List<_TodoItemData> _items;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _titleController = TextEditingController(text: widget.initialData!.title);
      _items = widget.initialData!.items
          .map((item) => _TodoItemData.fromItemData(item))
          .toList();
    } else {
      _titleController = TextEditingController();
      _items = [ _TodoItemData() ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_TodoItemData());
    });
  }

  void _removeItem(int index) {
    setState(() {
      if (_items.length > 1) {
        _items[index].dispose();
        _items.removeAt(index);
      }
    });
  }

  void _addSubItem(int itemIndex) {
    setState(() {
      _items[itemIndex].subControllers.add(TextEditingController());
    });
  }

  void _removeSubItem(int itemIndex, int subIndex) {
    setState(() {
      final subControllers = _items[itemIndex].subControllers;
      if (subControllers.isNotEmpty) {
        subControllers[subIndex].dispose();
        subControllers.removeAt(subIndex);
      }
    });
  }

  void _onSubmit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final items = _items.where((item) => item.controller.text.trim().isNotEmpty).toList();
    if (items.isEmpty) return;
    final data = TodoListData(title: title, items: items);
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增清單'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('標題', style: TextStyle(fontSize: 18)),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: '請輸入清單標題'),
            ),
            const SizedBox(height: 24),
            const Text('清單項目', style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: item.controller,
                                  decoration: InputDecoration(hintText: '項目 ${index + 1}'),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => _removeItem(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                tooltip: '新增細項',
                                onPressed: () => _addSubItem(index),
                              ),
                            ],
                          ),
                          if (item.subControllers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 24.0, top: 8.0),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: item.subControllers.length,
                                itemBuilder: (context, subIndex) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: item.subControllers[subIndex],
                                          decoration: InputDecoration(hintText: '細項 ${subIndex + 1}'),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                        onPressed: () => _removeSubItem(index, subIndex),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('新增欄位'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _onSubmit,
                  child: const Text('完成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoItemData {
  final TextEditingController controller;
  final List<TextEditingController> subControllers;
  _TodoItemData({String? title, List<String>? subItems})
      : controller = TextEditingController(text: title ?? ''),
        subControllers = (subItems ?? []).map((s) => TextEditingController(text: s)).toList();
  factory _TodoItemData.fromItemData(TodoItemData data) => _TodoItemData(
        title: data.title,
        subItems: data.subItems.map((s) => s.title).toList(),
      );
  void dispose() {
    controller.dispose();
    for (final c in subControllers) {
      c.dispose();
    }
  }
}
