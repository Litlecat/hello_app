# 專案說明

本專案包含三款 app：

1. **Flutter 午餐選擇 App**
2. **Flutter TodoList App**
3. **React Native 午餐選擇 App**

---

## 1. Flutter 午餐選擇 App

- 位置：`lib/main.dart`
- 啟動方式：

```bash
flutter run -t lib/main.dart
```

- 若要讓 app 斷線後也能正常啟動，請產生 release APK：

```bash
flutter build apk --release
```
APK 會在 `build/app/outputs/flutter-apk/app-release.apk`

安裝到手機：
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

> Release 版本安裝後，拔掉 USB 或關閉電腦，app 依然可以獨立運作。

---

## 2. Flutter TodoList App

- 位置：`lib/todo_app.dart`
- 啟動方式：

```bash
flutter run -t lib/todo_app.dart
```

---

## 3. React Native 午餐選擇 App

- 位置：`lunch_App/`（整個資料夾）
- 啟動方式：

### (1) 進入專案資料夾
```bash
cd lunch_App
```

### (2) 啟動 Metro 伺服器
```bash
npm start
```

### (3) 安裝並執行到 Android 模擬器或實體機
```bash
npx react-native run-android
```

### (4) （如要執行 iOS，需在 Mac 並安裝好 Xcode）
```bash
npx react-native run-ios
```

### (5) 產生 Release APK（讓 app 斷線後也能正常啟動）

> React Native 在開發模式下，app 啟動時會從電腦（Metro 伺服器）即時載入 JS 程式碼，必須連線。若要讓 app 斷線後也能正常啟動，請打包 release 版本：

```bash
cd lunch_App/android
./gradlew assembleRelease
```
APK 會在 `lunch_App/android/app/build/outputs/apk/release/app-release.apk`

安裝到手機：
```bash
adb install app/build/outputs/apk/release/app-release.apk
```

> Release 版本安裝後，拔掉 USB 或關閉 Metro 伺服器，app 依然可以獨立運作。

---

## 如何選擇特定設備執行 app

### Flutter
1. 先查詢所有可用設備：
   ```bash
   flutter devices
   ```
2. 指定設備執行（以設備 ID 為例）：
   ```bash
   flutter run -d <device_id> -t lib/main.dart
   flutter run -d <device_id> -t lib/todo_app.dart
   ```
   - 例如：
     ```bash
     flutter run -d emulator-5554 -t lib/main.dart
     flutter run -d 35121JEHN14913 -t lib/todo_app.dart
     ```

### React Native
1. 查詢所有可用 Android 設備：
   ```bash
   adb devices
   ```
2. 指定設備執行（以設備 ID 為例）：
   ```bash
   npx react-native run-android --deviceId <device_id>
   ```
   - 例如：
     ```bash
     npx react-native run-android --deviceId emulator-5554
     npx react-native run-android --deviceId 35121JEHN14913
     ```
3. iOS 可用模擬器名稱：
   ```bash
   npx react-native run-ios --list-devices
   npx react-native run-ios --device "iPhone 15"
   ```

---

## 小提醒
- Flutter 專案只能同時執行一個入口（main.dart 或 todo_app.dart），要切換就改 `-t` 參數。
- React Native 專案要先啟動 Metro（npm start），再 run-android/run-ios。
- 三個 app 互不影響，可以同時開啟不同模擬器或設備測試。

---

## 在 Cursor 中操作

- **開啟整合終端**：按下 `Ctrl/Cmd + J` 或點擊底部 Terminal 面板。
- **同時開多個終端**：點 `+` 新增分頁；一個跑 Metro/Flutter，另一個跑 build 或安裝。
- **常用指令（直接在 Cursor 終端執行）**：
  - Flutter（午餐 App）
    ```bash
    flutter run -t lib/main.dart
    flutter build apk --release -t lib/main.dart
    ```
  - Flutter（TodoList App）
    ```bash
    flutter run -t lib/todo_app.dart
    flutter build apk --release -t lib/todo_app.dart
    ```
  - React Native（啟動與打包）
    ```bash
    cd lunch_App
    npm start
    # 另開一個終端
    npx react-native run-android
    # 產出 release APK
    cd lunch_App/android && ./gradlew assembleRelease
    ```
- **裝置切換**：在終端先用 `flutter devices` 或 `adb devices` 查詢，再帶入 README 上述 `-d` 或 `--deviceId` 參數。
- **常見連線問題（RN）**：如果 8081 已被占用，可在終端輸入：
  ```bash
  kill -9 $(lsof -ti:8081)
  ```

---

如有任何問題，歡迎隨時詢問！
