# iOS 短篇 1｜iOS 極速通關：先跑起來

## 前言：為什麼需要這篇？

嘿，如果你已經跟著主系列把 Android 版本跑起來了，那 iOS 版本其實沒那麼可怕。但 iOS 確實有幾個「必經之路」：Xcode、簽章、Bundle ID，還有那個讓人又愛又恨的 CocoaPods。

這篇的目標很簡單：**一次就能在 iOS 上跑起來**，不管是模擬器還是實機。我們不會深入討論複雜的簽章設定，只求「能動就好」。

## 1. 前置需求檢查

### 必備工具
- **macOS**：這個不用說，iOS 開發只能在 Mac 上
- **Xcode**：從 App Store 下載最新版（通常 15GB+）
- **Command Line Tools**：Xcode 內建，但需要手動安裝
- **CocoaPods**：iOS 的套件管理工具
- **Apple ID**：免費帳號就夠了

### 檢查指令
```bash
# 檢查 Xcode 版本
xcodebuild -version

# 檢查 Command Line Tools
xcode-select --print-path

# 檢查 CocoaPods
pod --version
```

**截圖 1**：終端機執行 `xcodebuild -version` 和 `pod --version` 的結果

## 2. 安裝與設定

### 安裝 Command Line Tools
如果上面檢查失敗，執行：
```bash
sudo xcode-select --install
```

### 安裝 CocoaPods
```bash
sudo gem install cocoapods
```

## 3. Flutter iOS 起跑

### 檢查 Flutter iOS 支援
```bash
flutter doctor
```

你應該會看到類似這樣的輸出：
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain
[✓] Xcode - develop for iOS and macOS
[✓] Chrome - develop for the web
[✓] VS Code
```

### 開啟 iOS 模擬器
```bash
# 列出可用的模擬器
xcrun simctl list devices

# 開啟模擬器（選一個 iPhone）
open -a Simulator
```

### 設定 Bundle ID 和簽章（最短設定）
在 Xcode 中開啟 `ios/Runner.xcworkspace`：

1. 選擇 Runner 專案
2. 在 General 標籤中找到 Bundle Identifier，改成唯一名稱
3. 在 Signing & Capabilities 標籤中勾選 "Automatically manage signing"

**截圖 2**：Xcode 的 Bundle ID 和簽章設定畫面（兩個設定在同一張截圖）

### 啟動 Flutter iOS
```bash
# 在 Flutter 專案目錄中
flutter run -d ios
```

**截圖 3**：Flutter 在 iOS 模擬器中成功啟動的畫面

## 4. React Native iOS 起跑

### 安裝 iOS 依賴
```bash
# 在 React Native 專案目錄中
cd ios && pod install && cd ..
```

### 設定 Bundle ID
同樣在 Xcode 中開啟 `ios/LunchAppRN.xcworkspace`（注意是 .xcworkspace，不是 .xcodeproj）

### 啟動 React Native iOS
```bash
npx react-native run-ios
```

**截圖 4**：React Native 在 iOS 模擬器中成功啟動的畫面

## 5. 地圖/URL 相容性

### Apple Maps 備援
如果使用者沒有安裝 Google Maps，iOS 會自動使用 Apple Maps：

```dart
// Flutter 版本
final Uri mapsUri = Uri.parse(
  'https://maps.apple.com/?q=${Uri.encodeComponent(selectedLunch)}'
);
```

```javascript
// React Native 版本
const mapsUrl = `https://maps.apple.com/?q=${encodeURIComponent(selectedLunch)}`;
```

### 中文編碼測試
測試搜尋「牛肉麵」是否正確顯示：

**截圖 5**：在 iOS 模擬器中測試地圖搜尋功能，顯示 Apple Maps 開啟並搜尋「牛肉麵」的結果

## 6. 驗收清單

### 基本功能
- [ ] iOS 模擬器可正常啟動
- [ ] 主按鈕可點擊
- [ ] 抽籤功能正常
- [ ] 結果頁可返回/確認
- [ ] 地圖搜尋可開啟（Apple Maps 或 Google Maps）

### 進階功能（如果已實作）
- [ ] 新增/刪除午餐選項
- [ ] 重啟 App 後資料仍在
- [ ] 排序功能正常

## 7. 速查表：常見錯誤與修復

### 錯誤 1：CocoaPods 相關
```
[!] CocoaPods could not find compatible versions
```
**修復**：
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### 錯誤 2：簽章問題
```
Code signing error: No profiles for 'com.yourname.lunchapp' were found
```
**修復**：在 Xcode 中重新選擇 Team，或修改 Bundle ID


### 錯誤 3：Metro 連線問題
```
Metro bundler is not running
```
**修復**：
```bash
npx react-native start --reset-cache
```

### 錯誤 4：Xcode 版本不相容
```
This version of the app was built with an older version of Xcode
```
**修復**：更新 Xcode 到最新版本，或重新建置



## 結語

iOS 開發的門檻主要在於工具鏈設定，一旦跑起來，後續的開發體驗其實很順暢。重點是：

1. **一次設定好**：Xcode、CocoaPods、簽章
2. **模擬器先跑通**：專注於功能開發，模擬器已足夠
3. **遇到錯誤別慌**：大部分都是工具鏈問題，不是程式邏輯問題

如果你已經在 Android 上跑過主系列，iOS 版本只是換個平台而已，核心邏輯完全一樣。

下一章我們會回到主系列，繼續完善功能。iOS 的進階設定（如實機測試、推送通知、App Store 發布）我們會在其他短篇中討論。

---

**準備好了嗎？讓我們開始截圖吧！** 📱
