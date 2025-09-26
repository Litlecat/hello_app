import React, {useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  Alert,
  Linking,
} from 'react-native';

interface ResultPageProps {
  selectedLunch: string;
  lunchList: string[];
  onConfirm: (lunch: string, date: string) => void;
  onBack: () => void;
}

const ResultPage: React.FC<ResultPageProps> = ({
  selectedLunch,
  lunchList,
  onConfirm,
  onBack,
}) => {
  const [currentLunch, setCurrentLunch] = useState(selectedLunch);

  // 重新選擇
  const handleRefresh = () => {
    const randomIndex = Math.floor(Math.random() * lunchList.length);
    setCurrentLunch(lunchList[randomIndex]);
  };

  // 確定選擇
  const handleConfirm = () => {
    const now = new Date();
    const dateString = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    
    onConfirm(currentLunch, dateString);
    onBack();
  };

  // 開啟 Google Maps 搜尋
  const handleSearch = () => {
    const encodedQuery = encodeURIComponent(currentLunch);
    const url = `https://www.google.com/maps/search/${encodedQuery}`;
    
    Linking.openURL(url).catch(err => {
      Alert.alert('錯誤', '無法開啟 Google Maps');
      console.error('開啟 Google Maps 失敗:', err);
    });
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#FF6B35" />
      
      {/* 返回按鈕和標題 */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.backButton} onPress={onBack}>
          <Text style={styles.backButtonText}>←</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>選擇結果</Text>
      </View>

      {/* 主要結果顯示區域 */}
      <View style={styles.mainContent}>
        <View style={styles.resultCard}>
          <Text style={styles.resultIcon}>🍽️</Text>
          <Text style={styles.resultSubtitle}>今天的午餐是...</Text>
          <Text style={styles.resultTitle}>{currentLunch}</Text>
        </View>

        {/* 按鈕區域 */}
        <View style={styles.buttonContainer}>
          {/* 搜尋按鈕 */}
          <TouchableOpacity style={styles.searchButton} onPress={handleSearch}>
            <Text style={styles.searchButtonIcon}>🔍</Text>
            <Text style={styles.searchButtonText}>開啟 Google Maps</Text>
          </TouchableOpacity>

          {/* 其他按鈕 */}
          <View style={styles.otherButtons}>
            <TouchableOpacity style={styles.refreshButton} onPress={handleRefresh}>
              <Text style={styles.refreshButtonIcon}>🔄</Text>
              <Text style={styles.refreshButtonText}>重新選擇</Text>
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.confirmButton} onPress={handleConfirm}>
              <Text style={styles.confirmButtonIcon}>✓</Text>
              <Text style={styles.confirmButtonText}>確定選擇</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FF6B35',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 16,
  },
  backButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backButtonText: {
    fontSize: 24,
    color: 'white',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: 'white',
    marginLeft: 16,
  },
  mainContent: {
    flex: 1,
    paddingHorizontal: 24,
    justifyContent: 'center',
  },
  resultCard: {
    backgroundColor: 'white',
    borderRadius: 24,
    padding: 32,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 10,
    },
    shadowOpacity: 0.2,
    shadowRadius: 20,
    elevation: 10,
    marginBottom: 40,
  },
  resultIcon: {
    fontSize: 60,
    marginBottom: 20,
  },
  resultSubtitle: {
    fontSize: 20,
    color: '#666',
    marginBottom: 16,
  },
  resultTitle: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#FF6B35',
    textAlign: 'center',
  },
  buttonContainer: {
    gap: 16,
  },
  searchButton: {
    backgroundColor: 'white',
    borderRadius: 16,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 8,
  },
  searchButtonIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  searchButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FF6B35',
  },
  otherButtons: {
    flexDirection: 'row',
    gap: 12,
  },
  refreshButton: {
    flex: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    borderRadius: 12,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  refreshButtonIcon: {
    fontSize: 16,
    marginRight: 4,
  },
  refreshButtonText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FF6B35',
  },
  confirmButton: {
    flex: 1,
    backgroundColor: '#4CAF50',
    borderRadius: 12,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  confirmButtonIcon: {
    fontSize: 16,
    marginRight: 4,
    color: 'white',
  },
  confirmButtonText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: 'white',
  },
});

export default ResultPage;
