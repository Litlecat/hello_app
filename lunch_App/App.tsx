// App.tsx - React Native 主程式
// 這是午餐選擇 App 的主組件，負責所有 UI 與邏輯
// --------------------------------------------------

import React, {useState, useEffect} from 'react';
import {
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  Alert,
  TextInput,
  Modal,
  FlatList,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import ResultPage from './ResultPage';

// -----------------------------
// 預設午餐清單（初次啟動時顯示）
// -----------------------------
const DEFAULT_LUNCH_LIST = [
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

// LunchItem 型別（目前未用到，保留範例）
interface LunchItem {
  id: string;
  name: string;
}

// -----------------------------
// App 主組件
// -----------------------------
const App = (): React.JSX.Element => {
  // lunchList: 午餐選項清單（可編輯，會儲存到本地）
  const [lunchList, setLunchList] = useState<string[]>(DEFAULT_LUNCH_LIST);
  // isEditMode: 是否進入編輯模式
  const [isEditMode, setIsEditMode] = useState(false);
  // confirmedLunch: 上次確定的午餐選項
  const [confirmedLunch, setConfirmedLunch] = useState<string | null>(null);
  // confirmedDate: 上次確定的日期時間
  const [confirmedDate, setConfirmedDate] = useState<string | null>(null);
  // showAddModal: 是否顯示新增午餐選項的對話框
  const [showAddModal, setShowAddModal] = useState(false);
  // newLunchItem: 新增午餐選項的輸入內容
  const [newLunchItem, setNewLunchItem] = useState('');
  // showResultPage: 是否顯示結果頁面
  const [showResultPage, setShowResultPage] = useState(false);
  // selectedLunch: 當前隨機選中的午餐
  const [selectedLunch, setSelectedLunch] = useState('');

  // -----------------------------
  // 載入本地儲存的午餐清單（只在第一次啟動時執行）
  // -----------------------------
  useEffect(() => {
    loadLunchList();
  }, []);

  // 從 AsyncStorage 載入午餐清單
  const loadLunchList = async () => {
    try {
      const savedList = await AsyncStorage.getItem('lunch_list');
      if (savedList) {
        setLunchList(JSON.parse(savedList));
      }
    } catch (error) {
      console.error('載入午餐清單失敗:', error);
    }
  };

  // 將午餐清單儲存到本地（每次新增/刪除都會呼叫）
  const saveLunchList = async (newList: string[]) => {
    try {
      await AsyncStorage.setItem('lunch_list', JSON.stringify(newList));
      setLunchList(newList);
    } catch (error) {
      console.error('儲存午餐清單失敗:', error);
    }
  };

  // -----------------------------
  // 隨機選擇午餐，並顯示結果頁面
  // -----------------------------
  const handleRandomSelect = () => {
    if (lunchList.length === 0) {
      Alert.alert('提示', '請先新增午餐選項');
      return;
    }
    const randomIndex = Math.floor(Math.random() * lunchList.length);
    const lunch = lunchList[randomIndex];
    setSelectedLunch(lunch);
    setShowResultPage(true);
  };

  // -----------------------------
  // 處理結果頁面「確定」按鈕，記錄選擇與時間
  // -----------------------------
  const handleResultConfirm = (lunch: string, date: string) => {
    setConfirmedLunch(lunch);
    setConfirmedDate(date);
    setShowResultPage(false);
  };

  // -----------------------------
  // 返回主頁面（從結果頁面返回）
  // -----------------------------
  const handleBackToMain = () => {
    setShowResultPage(false);
  };

  // -----------------------------
  // 新增午餐選項（編輯模式下）
  // -----------------------------
  const handleAddLunch = () => {
    if (newLunchItem.trim() === '') {
      Alert.alert('提示', '請輸入午餐選項');
      return;
    }
    if (lunchList.includes(newLunchItem.trim())) {
      Alert.alert('提示', '此選項已存在');
      return;
    }
    const newList = [...lunchList, newLunchItem.trim()];
    saveLunchList(newList);
    setNewLunchItem('');
    setShowAddModal(false);
  };

  // -----------------------------
  // 刪除午餐選項（編輯模式下）
  // -----------------------------
  const handleDeleteLunch = (item: string) => {
    Alert.alert(
      '確認刪除',
      `確定要刪除「${item}」嗎？`,
      [
        {text: '取消', style: 'cancel'},
        {
          text: '刪除',
          style: 'destructive',
          onPress: () => {
            const newList = lunchList.filter(lunch => lunch !== item);
            saveLunchList(newList);
          }
        }
      ]
    );
  };

  // -----------------------------
  // 如果顯示結果頁面，渲染結果頁面（ResultPage）
  // -----------------------------
  if (showResultPage) {
    return (
      <ResultPage
        selectedLunch={selectedLunch}
        lunchList={lunchList}
        onConfirm={handleResultConfirm}
        onBack={handleBackToMain}
      />
    );
  }

  // -----------------------------
  // 主畫面 UI
  // -----------------------------
  return (
    <SafeAreaView style={styles.container}>
      {/* 狀態列顏色 */}
      <StatusBar barStyle="light-content" backgroundColor="#FF6B35" />
      
      {/* 頂部標題區域 */}
      <View style={styles.header}>
        <View style={styles.headerContent}>
          <View style={styles.headerRow}>
            <View style={styles.headerSpacer} />
            {/* 餐盤 emoji 當作 app icon */}
            <Text style={styles.headerIcon}>🍽️</Text>
            {/* 編輯模式切換按鈕 */}
            <TouchableOpacity
              style={styles.editButton}
              onPress={() => setIsEditMode(!isEditMode)}
            >
              <Text style={styles.editButtonText}>
                {isEditMode ? '✓' : '✏️'}
              </Text>
            </TouchableOpacity>
          </View>
          {/* 標題與副標題 */}
          <Text style={styles.title}>午餐吃什麼</Text>
          <Text style={styles.subtitle}>
            {isEditMode ? '編輯午餐選項' : '讓命運決定你的午餐吧！'}
          </Text>
        </View>
      </View>

      {/* 主要內容區域 */}
      <View style={styles.mainContent}>
        {isEditMode ? (
          // 編輯模式 UI
          <View style={styles.editContainer}>
            <View style={styles.editHeader}>
              <Text style={styles.editTitle}>午餐選項</Text>
              {/* 新增選項按鈕 */}
              <TouchableOpacity
                style={styles.addButton}
                onPress={() => setShowAddModal(true)}
              >
                <Text style={styles.addButtonText}>+</Text>
              </TouchableOpacity>
            </View>
            {/* 午餐選項列表 */}
            <FlatList
              data={lunchList}
              keyExtractor={(item, index) => `${item}-${index}`}
              renderItem={({item}) => (
                <View style={styles.lunchItem}>
                  <Text style={styles.lunchItemText}>{item}</Text>
                  {/* 刪除按鈕 */}
                  <TouchableOpacity
                    style={styles.deleteButton}
                    onPress={() => handleDeleteLunch(item)}
                  >
                    <Text style={styles.deleteButtonText}>🗑️</Text>
                  </TouchableOpacity>
                </View>
              )}
              style={styles.lunchList}
            />
          </View>
        ) : (
          // 正常模式 UI
          <View style={styles.normalMode}>
            {/* 隨機選擇按鈕 */}
            <TouchableOpacity
              style={styles.mainButton}
              onPress={handleRandomSelect}
            >
              <Text style={styles.mainButtonIcon}>🎲</Text>
              <Text style={styles.mainButtonText}>點我選擇！</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      {/* 歷史記錄區域（顯示上次選擇） */}
      {confirmedLunch && (
        <View style={styles.historyContainer}>
          <View style={styles.historyHeader}>
            <Text style={styles.historyIcon}>📝</Text>
            <Text style={styles.historyTitle}>上次選擇</Text>
          </View>
          <Text style={styles.historyLunch}>{confirmedLunch}</Text>
          <Text style={styles.historyDate}>日期：{confirmedDate}</Text>
        </View>
      )}

      {/* 新增午餐選項的 Modal 對話框 */}
      <Modal
        visible={showAddModal}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setShowAddModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>新增午餐選項</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="請輸入午餐選項"
              value={newLunchItem}
              onChangeText={setNewLunchItem}
              autoFocus={true}
            />
            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setShowAddModal(false)}
              >
                <Text style={styles.cancelButtonText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.confirmButton]}
                onPress={handleAddLunch}
              >
                <Text style={styles.confirmButtonText}>新增</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
};

// -----------------------------
// 樣式區（StyleSheet）
// -----------------------------
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FF6B35',
  },
  header: {
    paddingVertical: 20,
    paddingHorizontal: 24,
  },
  headerContent: {
    alignItems: 'center',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: 16,
  },
  headerSpacer: {
    width: 40,
  },
  headerIcon: {
    fontSize: 60,
  },
  editButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  editButtonText: {
    fontSize: 28,
    color: 'white',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: 'white',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: 'rgba(255, 255, 255, 0.7)',
  },
  mainContent: {
    flex: 1,
    paddingHorizontal: 24,
    justifyContent: 'center',
  },
  normalMode: {
    alignItems: 'center',
  },
  mainButton: {
    width: 200,
    height: 200,
    backgroundColor: 'white',
    borderRadius: 100,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 10,
    },
    shadowOpacity: 0.2,
    shadowRadius: 20,
    elevation: 10,
  },
  mainButtonIcon: {
    fontSize: 50,
    marginBottom: 8,
  },
  mainButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FF6B35',
  },
  editContainer: {
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    borderRadius: 16,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 5,
    },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 5,
  },
  editHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  editTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#FF6B35',
  },
  addButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addButtonText: {
    fontSize: 24,
    color: '#FF6B35',
  },
  lunchList: {
    maxHeight: 300,
  },
  lunchItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'white',
    padding: 16,
    marginVertical: 4,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  lunchItemText: {
    fontSize: 16,
    fontWeight: '500',
    flex: 1,
  },
  deleteButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteButtonText: {
    fontSize: 20,
  },
  historyContainer: {
    margin: 24,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    borderRadius: 16,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 5,
    },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 5,
  },
  historyHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  historyIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  historyTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FF6B35',
  },
  historyLunch: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  historyDate: {
    fontSize: 14,
    color: '#666',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: 'white',
    borderRadius: 16,
    padding: 24,
    width: '80%',
    maxWidth: 300,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 16,
    textAlign: 'center',
  },
  modalInput: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    marginBottom: 20,
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginHorizontal: 4,
  },
  cancelButton: {
    backgroundColor: '#f5f5f5',
  },
  confirmButton: {
    backgroundColor: '#FF6B35',
  },
  cancelButtonText: {
    color: '#666',
    fontWeight: 'bold',
  },
  confirmButtonText: {
    color: 'white',
    fontWeight: 'bold',
  },
});

export default App;