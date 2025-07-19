# PyQt6 GUI アーキテクチャ設計書

## Microsoft 365管理ツール Python移行 - フロントエンド設計

### 1. アーキテクチャ概要

```
Microsoft365ManagementToolsGUI (PyQt6)
├── QMainWindow (1450×950)
│   ├── MenuBar (Microsoft 365 統合メニュー)
│   ├── ToolBar (認証・接続・設定)
│   ├── CentralWidget (TabWidget)
│   │   ├── 機能タブ群 (6セクション×26機能)
│   │   └── ログタブ群 (3種類のログ表示)
│   ├── StatusBar (接続状態・進捗表示)
│   └── DockWidgets (拡張機能用)
```

### 2. メインウィンドウ仕様（QMainWindow）

#### 基本設定
```python
class Microsoft365ManagementMainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        
        # ウィンドウ基本設定
        self.setWindowTitle("Microsoft 365統合管理ツール Python版 v3.0")
        self.setGeometry(100, 100, 1450, 950)
        self.setMinimumSize(1200, 800)
        
        # アイコン設定
        self.setWindowIcon(QIcon("resources/icons/ms365_icon.png"))
        
        # 中央ウィジェット
        self.setCentralWidget(self.create_central_widget())
        
        # メニュー・ツールバー・ステータスバー
        self.create_menu_bar()
        self.create_tool_bar()
        self.create_status_bar()
```

#### スタイルシート（Microsoft デザイン準拠）
```python
MAIN_WINDOW_STYLE = """
QMainWindow {
    background: qlineargradient(x1: 0, y1: 0, x2: 0, y2: 1,
                               stop: 0 #f8f9fa, stop: 1 #e9ecef);
    color: #212529;
    font-family: 'Segoe UI', 'Yu Gothic UI', sans-serif;
}

QPushButton {
    background-color: #0078d4;
    border: 2px solid #005a9e;
    border-radius: 4px;
    color: white;
    font-weight: bold;
    font-size: 10pt;
    padding: 8px 16px;
    min-width: 180px;
    min-height: 40px;
}

QPushButton:hover {
    background-color: #106ebe;
    border-color: #005a9e;
}

QPushButton:pressed {
    background-color: #005a9e;
}

QPushButton:disabled {
    background-color: #6c757d;
    border-color: #6c757d;
    color: #adb5bd;
}
"""
```

### 3. タブ構造設計（QTabWidget）

#### 機能タブ（上部） - 6セクション
```python
class FunctionTabWidget(QTabWidget):
    def __init__(self):
        super().__init__()
        self.setTabPosition(QTabWidget.TabPosition.North)
        
        # 6つの機能セクション
        self.addTab(self.create_regular_reports_tab(), "📊 定期レポート")
        self.addTab(self.create_analytics_tab(), "🔍 分析レポート") 
        self.addTab(self.create_entra_id_tab(), "👥 Entra ID管理")
        self.addTab(self.create_exchange_tab(), "📧 Exchange Online")
        self.addTab(self.create_teams_tab(), "💬 Teams管理")
        self.addTab(self.create_onedrive_tab(), "💾 OneDrive管理")
```

#### ログタブ（下部） - 3種類
```python
class LogTabWidget(QTabWidget):
    def __init__(self):
        super().__init__()
        self.setTabPosition(QTabWidget.TabPosition.North)
        
        # 3つのログビュー
        self.addTab(self.create_execution_log_tab(), "🔍 実行ログ")
        self.addTab(self.create_error_log_tab(), "❌ エラーログ")
        self.addTab(self.create_prompt_tab(), "💻 プロンプト")
```

### 4. 26機能ボタン配置設計

#### セクション1: 定期レポート（6機能） - 3列2行
```python
def create_regular_reports_tab(self):
    widget = QWidget()
    layout = QGridLayout()
    
    # ボタン配列定義
    buttons = [
        ("📅 日次レポート", self.daily_report, 0, 0),
        ("📊 週次レポート", self.weekly_report, 0, 1),
        ("📈 月次レポート", self.monthly_report, 0, 2),
        ("📆 年次レポート", self.yearly_report, 1, 0),
        ("🧪 テスト実行", self.test_execution, 1, 1),
        ("📋 最新日次レポート表示", self.latest_daily_report, 1, 2)
    ]
    
    for text, handler, row, col in buttons:
        btn = self.create_function_button(text, handler)
        layout.addWidget(btn, row, col)
    
    widget.setLayout(layout)
    return widget
```

#### セクション2: 分析レポート（5機能） - 3列2行
```python
def create_analytics_tab(self):
    widget = QWidget()
    layout = QGridLayout()
    
    buttons = [
        ("📊 ライセンス分析", self.license_analysis, 0, 0),
        ("📈 使用状況分析", self.usage_analysis, 0, 1),
        ("⚡ パフォーマンス分析", self.performance_analysis, 0, 2),
        ("🛡️ セキュリティ分析", self.security_analysis, 1, 0),
        ("🔍 権限監査", self.permission_audit, 1, 1)
    ]
    
    for text, handler, row, col in buttons:
        btn = self.create_function_button(text, handler)
        layout.addWidget(btn, row, col)
        
    widget.setLayout(layout)
    return widget
```

#### セクション3-6: 各管理系（4機能ずつ） - 2列2行中央寄せ
```python
def create_entra_id_tab(self):
    widget = QWidget()
    layout = QGridLayout()
    layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
    
    buttons = [
        ("👥 ユーザー一覧", self.user_list, 0, 0),
        ("🔐 MFA状況", self.mfa_status, 0, 1),
        ("🛡️ 条件付きアクセス", self.conditional_access, 1, 0),
        ("📝 サインインログ", self.signin_logs, 1, 1)
    ]
    
    for text, handler, row, col in buttons:
        btn = self.create_function_button(text, handler)
        layout.addWidget(btn, row, col)
    
    widget.setLayout(layout)
    return widget
```

### 5. リアルタイムログシステム（Write-GuiLog互換）

#### ログクラス設計
```python
class GuiLogLevel(Enum):
    INFO = ("ℹ️", "#0078d4")      # 青色情報
    SUCCESS = ("✅", "#107c10")   # 緑色成功
    WARNING = ("⚠️", "#ff8c00")   # オレンジ警告  
    ERROR = ("❌", "#d13438")     # 赤色エラー
    DEBUG = ("🔍", "#5c2d91")     # 紫色デバッグ

class GuiLogger(QObject):
    log_message = pyqtSignal(str, str, str)  # message, level, timestamp
    
    def __init__(self):
        super().__init__()
        
    def write_gui_log(self, message: str, level: GuiLogLevel = GuiLogLevel.INFO, 
                     show_notification: bool = False):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        icon, color = level.value
        
        formatted_message = f"[{timestamp}] {icon} {message}"
        self.log_message.emit(formatted_message, color, timestamp)
        
        if show_notification:
            self.show_notification(message, level)
```

#### ログビューア実装
```python
class LogViewer(QWidget):
    def __init__(self):
        super().__init__()
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # 実行ログテキストエリア
        self.log_text = QTextEdit()
        self.log_text.setFont(QFont("Consolas", 9))
        self.log_text.setReadOnly(True)
        self.log_text.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e1e;
                color: #ffffff;
                border: 1px solid #3c3c3c;
                border-radius: 4px;
            }
        """)
        
        # プロンプト入力エリア
        prompt_layout = QHBoxLayout()
        self.prompt_input = QLineEdit()
        self.prompt_input.setPlaceholderText("PowerShellコマンドを入力...")
        self.execute_btn = QPushButton("実行")
        self.clear_btn = QPushButton("クリア")
        
        prompt_layout.addWidget(self.prompt_input, 8)
        prompt_layout.addWidget(self.execute_btn, 1)
        prompt_layout.addWidget(self.clear_btn, 1)
        
        layout.addWidget(self.log_text, 9)
        layout.addWidget(QWidget(), 0)  # spacer
        layout.addLayout(prompt_layout, 1)
        
        self.setLayout(layout)
        
    @pyqtSlot(str, str, str)
    def append_log(self, message: str, color: str, timestamp: str):
        # スレッドセーフなログ追加
        cursor = self.log_text.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        
        # HTMLフォーマットでカラーログ
        html_message = f'<span style="color: {color};">{message}</span><br>'
        cursor.insertHtml(html_message)
        
        # 自動スクロール
        self.log_text.setTextCursor(cursor)
        self.log_text.ensureCursorVisible()
        
        # ログトリミング（パフォーマンス対策）
        self.trim_log_if_needed()
```

### 6. Microsoft 365 API統合レイヤー

#### 認証マネージャー
```python
class Microsoft365AuthManager(QObject):
    auth_status_changed = pyqtSignal(bool, str)  # connected, status_message
    
    def __init__(self):
        super().__init__()
        self.graph_client = None
        self.exchange_client = None
        self.is_authenticated = False
        
    async def authenticate(self):
        try:
            # MSAL Python による認証
            config = load_config()
            auth_app = msal.ConfidentialClientApplication(
                client_id=config["client_id"],
                client_credential=config["client_secret"],
                authority=f"https://login.microsoftonline.com/{config['tenant_id']}"
            )
            
            result = auth_app.acquire_token_for_client(
                scopes=["https://graph.microsoft.com/.default"]
            )
            
            if "access_token" in result:
                self.setup_clients(result["access_token"])
                self.is_authenticated = True
                self.auth_status_changed.emit(True, "認証成功")
            else:
                raise Exception(f"認証失敗: {result.get('error_description')}")
                
        except Exception as e:
            self.auth_status_changed.emit(False, f"認証エラー: {str(e)}")
```

#### API統合サービス
```python
class Microsoft365DataService(QObject):
    data_ready = pyqtSignal(dict)  # API結果データ
    
    def __init__(self, auth_manager: Microsoft365AuthManager):
        super().__init__()
        self.auth_manager = auth_manager
        
    async def get_user_list(self):
        """Entra ID ユーザー一覧取得"""
        if not self.auth_manager.is_authenticated:
            raise Exception("認証が必要です")
            
        try:
            # Microsoft Graph API呼び出し
            graph_client = self.auth_manager.graph_client
            users = await graph_client.users.get()
            
            # データ変換・フォーマット
            user_data = []
            for user in users.value:
                user_data.append({
                    "displayName": user.display_name,
                    "userPrincipalName": user.user_principal_name,
                    "mail": user.mail,
                    "accountEnabled": user.account_enabled
                })
                
            self.data_ready.emit({"type": "users", "data": user_data})
            
        except Exception as e:
            raise Exception(f"ユーザー情報取得エラー: {str(e)}")
```

### 7. レポート生成・ファイル出力

#### レポートジェネレーター
```python
class ReportGenerator(QObject):
    report_generated = pyqtSignal(str, str)  # csv_path, html_path
    
    def __init__(self):
        super().__init__()
        
    def generate_report(self, data: dict, report_type: str):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # CSVファイル生成
        csv_path = self.generate_csv(data, report_type, timestamp)
        
        # HTMLファイル生成
        html_path = self.generate_html(data, report_type, timestamp)
        
        self.report_generated.emit(csv_path, html_path)
        
    def generate_csv(self, data: dict, report_type: str, timestamp: str) -> str:
        output_dir = Path("Reports") / report_type
        output_dir.mkdir(parents=True, exist_ok=True)
        
        csv_path = output_dir / f"{report_type}_{timestamp}.csv"
        
        # pandasでCSV出力（UTF-8 BOM対応）
        df = pd.DataFrame(data["data"])
        df.to_csv(csv_path, index=False, encoding="utf-8-sig")
        
        return str(csv_path)
        
    def generate_html(self, data: dict, report_type: str, timestamp: str) -> str:
        output_dir = Path("Reports") / report_type  
        output_dir.mkdir(parents=True, exist_ok=True)
        
        html_path = output_dir / f"{report_type}_{timestamp}.html"
        
        # Jinja2テンプレートでHTML生成
        template = self.load_template(report_type)
        html_content = template.render(
            data=data["data"],
            timestamp=timestamp,
            report_type=report_type
        )
        
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(html_content)
            
        return str(html_path)
```

### 8. 設定管理（appsettings.json互換）

#### 設定マネージャー
```python
class ConfigManager:
    def __init__(self):
        self.config_path = Path("Config/appsettings.json")
        self.config = self.load_config()
        
    def load_config(self) -> dict:
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return self.create_default_config()
            
    def create_default_config(self) -> dict:
        default_config = {
            "GUI": {
                "AutoOpenFiles": True,
                "ShowPopupNotifications": True,
                "AlsoOpenCSV": False
            },
            "EntraID": {
                "TenantId": "${REACT_APP_MS_TENANT_ID}",
                "ClientId": "${REACT_APP_MS_CLIENT_ID}",
                "Scopes": [
                    "User.Read.All",
                    "Directory.Read.All",
                    "AuditLog.Read.All"
                ]
            }
        }
        
        # 設定ファイル作成
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.config_path, "w", encoding="utf-8") as f:
            json.dump(default_config, f, indent=2, ensure_ascii=False)
            
        return default_config
```

### 9. 非同期処理・スレッドセーフティ

#### ワーカースレッド設計
```python
class ApiWorker(QThread):
    data_received = pyqtSignal(dict)
    error_occurred = pyqtSignal(str)
    progress_updated = pyqtSignal(int)
    
    def __init__(self, api_service: Microsoft365DataService, operation: str):
        super().__init__()
        self.api_service = api_service
        self.operation = operation
        
    def run(self):
        try:
            if self.operation == "get_users":
                asyncio.run(self.api_service.get_user_list())
            elif self.operation == "get_licenses":
                asyncio.run(self.api_service.get_license_info())
            # ... 他の操作
            
        except Exception as e:
            self.error_occurred.emit(str(e))
```

### 10. テスト設計（pytest-qt）

#### GUIテストフレームワーク
```python
import pytest
from pytestqt import qtbot
from PyQt6.QtWidgets import QApplication

@pytest.fixture
def main_window(qtbot):
    window = Microsoft365ManagementMainWindow()
    qtbot.addWidget(window)
    return window

def test_main_window_initialization(main_window, qtbot):
    """メインウィンドウの初期化テスト"""
    assert main_window.windowTitle() == "Microsoft 365統合管理ツール Python版 v3.0"
    assert main_window.size().width() == 1450
    assert main_window.size().height() == 950

def test_button_click_events(main_window, qtbot):
    """ボタンクリックイベントテスト"""
    # 日次レポートボタンを検索
    daily_btn = main_window.findChild(QPushButton, "daily_report_btn")
    assert daily_btn is not None
    
    # ボタンクリックシミュレート
    with qtbot.waitSignal(main_window.report_generated, timeout=5000):
        qtbot.mouseClick(daily_btn, Qt.MouseButton.LeftButton)

def test_authentication_flow(main_window, qtbot):
    """認証フローテスト"""
    auth_manager = main_window.auth_manager
    
    with qtbot.waitSignal(auth_manager.auth_status_changed, timeout=10000):
        auth_manager.authenticate()
```

## 実装優先順位

### Phase 1: 基盤実装（高優先度）
1. ✅ **QMainWindow基盤構築**
2. ✅ **タブ構造実装** 
3. ✅ **26機能ボタン配置**
4. ✅ **基本スタイルシート適用**

### Phase 2: 核心機能（高優先度）  
5. **リアルタイムログシステム実装**
6. **Microsoft 365 API統合**
7. **認証マネージャー実装**
8. **データサービス統合**

### Phase 3: 高度機能（中優先度）
9. **レポート生成システム**
10. **ファイル出力機能**
11. **非同期処理対応**
12. **エラーハンドリング強化**

### Phase 4: 品質保証（高優先度）
13. **pytest-qt テストスイート**
14. **パフォーマンス最適化**
15. **アクセシビリティ対応**
16. **最終統合テスト**

この設計により、PowerShell版の全機能をPyQt6で完全再現し、さらに拡張性とメンテナンス性を向上させることができます。