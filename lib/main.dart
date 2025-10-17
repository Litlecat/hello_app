// main.dart

// 引入 Flutter 的 UI 套件
import 'package:flutter/material.dart';
// 引入 Dart 的數學套件，用於隨機數
import 'dart:math';
// 引入 Dart 的 JSON 套件，用於資料序列化
import 'dart:convert';
// 引入 url_launcher 套件，用於開啟網頁
import 'package:url_launcher/url_launcher.dart';
// 引入 shared_preferences 套件，用於本地資料儲存
import 'package:shared_preferences/shared_preferences.dart';

// 應用程式的進入點
void main() {
  // 啟動一個 Material 風格的應用程式
  // 將 MaterialApp 放在最外層，這樣它的子 Widget 才能使用導航（Navigator）等功能
  runApp(MaterialApp(
    title: '午餐幫你選',
    theme: ThemeData(
      primarySwatch: Colors.orange,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    // 應用程式的主頁面
    home: const MyApp(),
  ));
}

// MyApp：主頁面，一個可以管理狀態的 StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// _MyAppState：主頁面的狀態管理類別
class _MyAppState extends State<MyApp> {
  // 午餐清單
  List<String> _messageList = [
    '泰式料理',
    '火鍋',
    '酸菜魚',
    '水煮牛肉',
    '麥當勞',
    '牛丼',
    '披薩',
    '壽司',
    '拉麵',
    '早午餐店',
  ];

  // 狀態變數：用於記錄確定午餐的日期時間
  String? _confirmedDate;
  // 狀態變數：用於記錄確定的午餐選項
  String? _confirmedLunch;
  
  // 編輯模式狀態
  bool _isEditMode = false;
  
  // 儲存鍵值
  static const String _lunchListKey = 'lunch_list';

  @override
  void initState() {
    super.initState();
    _loadLunchList();
  }

  // 載入儲存的午餐清單
  Future<void> _loadLunchList() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedList = prefs.getString(_lunchListKey);
    if (savedList != null) {
      final List<dynamic> decodedList = json.decode(savedList);
      setState(() {
        _messageList = decodedList.cast<String>();
      });
    }
  }

  // 儲存午餐清單
  Future<void> _saveLunchList() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = json.encode(_messageList);
    await prefs.setString(_lunchListKey, encodedList);
  }

  // 處理按鈕點擊事件的方法
  // 使用 async/await，以便我們能等待新頁面返回的資料
  void _handleButtonPress() async {
    // 隨機選擇一個午餐選項
    final random = Random();
    final int index = random.nextInt(_messageList.length);
    final String selectedLunch = _messageList[index];

    // 導航到 ResultPage，並等待它返回一個結果 (這裡會是一個 Map)
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultPage(
          messageList: _messageList,
          initialText: selectedLunch,
        ),
      ),
    );

    // 檢查是否有返回結果，如果有的話就更新狀態
    if (result != null && result is Map) {
      setState(() {
        // 從 Map 中取出對應的值來更新狀態
        _confirmedDate = result['date'];
        _confirmedLunch = result['lunch'];
      });
    }
  }

  // 切換編輯模式
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  // 新增午餐選項
  void _addLunchOption() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新增午餐選項'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '請輸入午餐選項',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty && !_messageList.contains(text)) {
                  setState(() {
                    _messageList.add(text);
                  });
                  await _saveLunchList(); // 儲存到本地
                }
                Navigator.of(context).pop();
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  // 刪除午餐選項
  void _removeLunchOption(String option) async {
    setState(() {
      _messageList.remove(option);
    });
    await _saveLunchList(); // 儲存到本地
  }

  // 建構正常模式
  Widget _buildNormalMode() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 主要選擇按鈕
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: _handleButtonPress,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shuffle,
                      size: 50,
                      color: Color(0xFFFF6B35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '點我選擇！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 建構編輯模式
  Widget _buildEditMode() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '午餐選項',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
              IconButton(
                onPressed: _addLunchOption,
                icon: const Icon(
                  Icons.add_circle,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _messageList.length,
              itemBuilder: (context, index) {
                final option = _messageList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => _removeLunchOption(option),
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 建構主頁面的畫面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF6B35), // 橘色
              Color(0xFFFF8E53), // 淺橘色
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 頂部標題區域
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40), // 平衡空間
                          const Icon(
                            Icons.restaurant,
                            size: 60,
                            color: Colors.white,
                          ),
                          IconButton(
                            onPressed: _toggleEditMode,
                            icon: Icon(
                              _isEditMode ? Icons.check : Icons.edit,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '午餐吃什麼',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isEditMode ? '編輯午餐選項' : '讓命運決定你的午餐吧！',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 主要按鈕區域
                Expanded(
                  child: Center(
                    child: _isEditMode ? _buildEditMode() : _buildNormalMode(),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 歷史記錄區域
                if (_confirmedLunch != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: Color(0xFFFF6B35),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '上次選擇',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B35),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _confirmedLunch!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '日期：$_confirmedDate',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ResultPage：顯示午餐選擇結果的頁面
class ResultPage extends StatefulWidget {
  final List<String> messageList;
  final String initialText;

  const ResultPage({
    Key? key,
    required this.messageList,
    required this.initialText,
  }) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

// _ResultPageState：ResultPage 的狀態管理類別
class _ResultPageState extends State<ResultPage> {
  late String _currentText;

  // 初始化狀態
  @override
  void initState() {
    super.initState();
    _currentText = widget.initialText.trim();
  }

  // 處理「刷新」按鈕的點擊事件
  void _handleRefreshPress() {
    final random = Random();
    final int index = random.nextInt(widget.messageList.length);
    final String newText = widget.messageList[index];

    setState(() {
      _currentText = newText.trim();
    });
  }

  // 處理「確定」按鈕的點擊事件
  void _handleConfirmPress() {
    // 獲取當前日期時間
    final now = DateTime.now();
    // 格式化日期時間為 mm/dd
    final formattedDate = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    // 顯示歡呼訊息的 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('午餐已確定！🎉'),
        duration: Duration(seconds: 1), // 顯示一秒
      ),
    );

    // 在 SnackBar 顯示後，延遲返回主頁面，並傳遞格式化的日期
    Future.delayed(const Duration(seconds: 1), () {
      // 使用 pop() 方法返回上一頁，並將 formattedDate 作為結果傳回
      Navigator.of(context).pop({
        'date': formattedDate, // 將日期放入 Map
        'lunch': _currentText, // 將午餐選項放入 Map
      });
    });
  }

  // 處理「搜尋」按鈕的點擊事件
  void _handleSearchPress() async {
    // 構建地圖搜尋的網址，使用 encodeComponent 確保中文字元正確
    final String query = Uri.encodeComponent('${_currentText}');
    final Uri url;
    String buttonText;
    
    // 根據平台選擇地圖服務
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // iOS 使用 Apple Maps
      url = Uri.parse('https://maps.apple.com/?q=$query');
      buttonText = '開啟 Apple Maps';
    } else {
      // Android 使用 Google Maps
      url = Uri.parse('https://www.google.com/maps/search/$query');
      buttonText = '開啟 Google Maps';
    }

    // 嘗試開啟網址，不檢查 canLaunchUrl（因為模擬器可能誤判）
    try {
      await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      // 如果開啟失敗，顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法打開地圖：$e'),
        ),
      );
    }
  }

  // 建構 ResultPage 的畫面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF6B35),
              Color(0xFFFF8E53),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 返回按鈕
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Text(
                      '選擇結果',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // 主要結果顯示區域
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 結果卡片
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.restaurant_menu,
                                size: 60,
                                color: Color(0xFFFF6B35),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '今天的午餐是...',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentText,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF6B35),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // 按鈕區域
                        Column(
                          children: [
                            // 搜尋按鈕
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _handleSearchPress,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFFF6B35),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.search),
                                label: Text(
                                  Theme.of(context).platform == TargetPlatform.iOS 
                                    ? '開啟 Apple Maps' 
                                    : '開啟 Google Maps',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // 其他按鈕
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleRefreshPress,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.9),
                                        foregroundColor: const Color(0xFFFF6B35),
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.refresh, size: 20),
                                      label: const Text('重新選擇'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleConfirmPress,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check, size: 20),
                                      label: const Text('確定選擇'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}