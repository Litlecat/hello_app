// main.dart

// 引入 Flutter 的 UI 套件
import 'package:flutter/material.dart';
// 引入 Dart 的數學套件，用於隨機數
import 'dart:math';
// 引入 url_launcher 套件，用於開啟網頁
import 'package:url_launcher/url_launcher.dart';

// 應用程式的進入點
void main() {
  // 啟動一個 Material 風格的應用程式
  // 將 MaterialApp 放在最外層，這樣它的子 Widget 才能使用導航（Navigator）等功能
  runApp(const MaterialApp(
    title: '午餐幫你選',
    // 應用程式的主頁面
    home: MyApp(),
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
  final List<String> _messageList = [
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
    '西北風',
  ];

  // 狀態變數：用於記錄確定午餐的日期時間
  String? _confirmedDate;
  // 狀態變數：用於記錄確定的午餐選項
  String? _confirmedLunch;

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

  // 建構主頁面的畫面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('午餐吃什麼'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '點擊下面的按鈕！👇',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleButtonPress,
              child: const Text('點我！'),
            ),
            const SizedBox(height: 20),
            // 使用 Visibility 根據 _confirmedLunch 的狀態來顯示或隱藏文字
            Visibility(
              // 只有當 _confirmedLunch 不為空時才顯示
              visible: _confirmedLunch != null,
              child: Column(
                children: [
                  // 顯示確定的午餐選項
                  Text(
                    '上次確定的午餐：$_confirmedLunch',
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                  const SizedBox(height: 5), // 增加一些間距
                  // 顯示確定午餐的日期時間
                  Text(
                    '日期：$_confirmedDate',
                    style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ],
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
  String _insultText = '';
  bool _isLocked = false;

  // 初始化狀態
  @override
  void initState() {
    super.initState();
    _currentText = widget.initialText.trim();
    if (_currentText == '西北風') {
      _isLocked = true;
      _insultText = '面對現實吧，窮衰仔！';
    }
  }

  // 處理「刷新」按鈕的點擊事件
  void _handleRefreshPress() {
    if (_isLocked) {
      return;
    }

    final random = Random();
    final int index = random.nextInt(widget.messageList.length);
    final String newText = widget.messageList[index];

    setState(() {
      _currentText = newText.trim();
      if (_currentText == '西北風') {
        _insultText = '面對現實吧，窮衰仔！';
        _isLocked = true;
      }
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
    // 構建 Google 搜尋的網址，使用 encodeComponent 確保中文字元正確
    final String query = Uri.encodeComponent('${_currentText} 附近');
    final Uri url = Uri.parse('https://www.google.com/search?q=$query');

    // 檢查設備是否能打開這個網址
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // 用外部瀏覽器（如 Chrome）開啟
      );
    } else {
      // 如果不能開啟，顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無法打開瀏覽器！'),
        ),
      );
    }
  }

  // 建構 ResultPage 的畫面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇結果'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '今天的午餐是...',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              _currentText,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Visibility(
              visible: _isLocked,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _insultText,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // 使用 Column 將按鈕分組，讓搜尋按鈕獨立一行
            Column(
              children: [
                ElevatedButton(
                  onPressed: _isLocked ? null : _handleSearchPress,
                  child: const Text('搜尋午餐結果'),
                ),
                const SizedBox(height: 10), // 增加按鈕間距
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isLocked ? null : _handleRefreshPress,
                      child: const Text('刷新'),
                    ),
                    ElevatedButton(
                      onPressed: _handleConfirmPress,
                      child: const Text('確定'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('返回'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}