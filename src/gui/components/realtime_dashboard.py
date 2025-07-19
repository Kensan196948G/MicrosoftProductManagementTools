#!/usr/bin/env python3
"""
Real-time Dashboard Component - Phase 3 GUI統合加速
PyQt6 + WebSocket統合によるリアルタイムダッシュボード

Features:
- WebSocket Client統合
- 26機能統合Dashboard
- Real-time データ更新
- Interactive Progress表示
- Enterprise UI/UX

Author: Frontend Developer (dev0)
Version: 3.1.0
Date: 2025-07-19
"""

import sys
import json
import asyncio
import websockets
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass
from enum import Enum
import uuid
from pathlib import Path

try:
    from PyQt6.QtWidgets import (
        QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, 
        QPushButton, QLabel, QTextEdit, QProgressBar,
        QFrame, QScrollArea, QGroupBox, QTabWidget,
        QSplitter, QTableWidget, QTableWidgetItem,
        QHeaderView, QComboBox, QLineEdit, QCheckBox,
        QSlider, QSpinBox, QDateTimeEdit, QCalendarWidget
    )
    from PyQt6.QtCore import (
        Qt, QThread, QTimer, QObject, pyqtSignal, pyqtSlot,
        QPropertyAnimation, QEasingCurve, QRect, QSize,
        QDateTime, QUrl
    )
    from PyQt6.QtGui import (
        QFont, QIcon, QPixmap, QPainter, QPen, QBrush,
        QColor, QLinearGradient, QRadialGradient, QMovie
    )
    from PyQt6.QtCharts import (
        QChart, QChartView, QLineSeries, QBarSeries, 
        QBarSet, QPieSeries, QAreaSeries, QValueAxis,
        QDateTimeAxis, QBarCategoryAxis
    )
except ImportError as e:
    print(f"❌ PyQt6インポートエラー: {e}")
    print("インストール: pip install PyQt6 PyQt6-Charts")
    sys.exit(1)


class DashboardDataType(Enum):
    """ダッシュボードデータタイプ"""
    USER_ACTIVITY = "user_activity"
    LICENSE_USAGE = "license_usage"
    SECURITY_ALERTS = "security_alerts"
    PERFORMANCE_METRICS = "performance_metrics"
    SYSTEM_STATUS = "system_status"
    REAL_TIME_LOGS = "real_time_logs"


class ConnectionStatus(Enum):
    """WebSocket接続状態"""
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    RECONNECTING = "reconnecting"
    ERROR = "error"


@dataclass
class DashboardMetric:
    """ダッシュボードメトリクス"""
    id: str
    name: str
    value: Any
    unit: str = ""
    trend: float = 0.0  # -1.0 to 1.0
    status: str = "normal"  # normal, warning, critical
    last_updated: datetime = None


class WebSocketClient(QObject):
    """
    PyQt6統合WebSocketクライアント
    Real-time Dashboard用のWebSocket通信を管理
    """
    
    # シグナル定義
    connection_status_changed = pyqtSignal(str)  # status
    data_received = pyqtSignal(str, dict)  # data_type, data
    error_occurred = pyqtSignal(str)  # error_message
    
    def __init__(self, server_url: str = "ws://localhost:8000/ws"):
        super().__init__()
        self.server_url = server_url
        self.websocket = None
        self.status = ConnectionStatus.DISCONNECTED
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 5
        self.reconnect_timer = QTimer()
        self.reconnect_timer.timeout.connect(self.reconnect)
        
    async def connect(self):
        """WebSocket接続"""
        try:
            self.status = ConnectionStatus.CONNECTING
            self.connection_status_changed.emit(self.status.value)
            
            self.websocket = await websockets.connect(self.server_url)
            
            self.status = ConnectionStatus.CONNECTED
            self.connection_status_changed.emit(self.status.value)
            self.reconnect_attempts = 0
            
            # メッセージ受信ループを開始
            asyncio.create_task(self.listen_for_messages())
            
        except Exception as e:
            self.status = ConnectionStatus.ERROR
            self.connection_status_changed.emit(self.status.value)
            self.error_occurred.emit(f"接続エラー: {str(e)}")
            self.schedule_reconnect()
    
    async def disconnect(self):
        """WebSocket切断"""
        if self.websocket:
            await self.websocket.close()
        self.status = ConnectionStatus.DISCONNECTED
        self.connection_status_changed.emit(self.status.value)
    
    async def send_message(self, message_type: str, data: dict):
        """メッセージ送信"""
        if self.websocket and self.status == ConnectionStatus.CONNECTED:
            try:
                message = {
                    "type": message_type,
                    "data": data,
                    "timestamp": datetime.now().isoformat()
                }
                await self.websocket.send(json.dumps(message))
            except Exception as e:
                self.error_occurred.emit(f"送信エラー: {str(e)}")
                await self.connect()  # 再接続試行
    
    async def listen_for_messages(self):
        """メッセージ受信ループ"""
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)
                    message_type = data.get("type", "unknown")
                    message_data = data.get("data", {})
                    
                    # PyQt6シグナルでデータを通知
                    self.data_received.emit(message_type, message_data)
                    
                except json.JSONDecodeError as e:
                    self.error_occurred.emit(f"JSON解析エラー: {str(e)}")
                    
        except websockets.exceptions.ConnectionClosed:
            self.status = ConnectionStatus.DISCONNECTED
            self.connection_status_changed.emit(self.status.value)
            self.schedule_reconnect()
        except Exception as e:
            self.error_occurred.emit(f"受信エラー: {str(e)}")
            self.schedule_reconnect()
    
    def schedule_reconnect(self):
        """再接続スケジュール"""
        if self.reconnect_attempts < self.max_reconnect_attempts:
            self.status = ConnectionStatus.RECONNECTING
            self.connection_status_changed.emit(self.status.value)
            
            # 指数バックオフで再接続間隔を調整
            delay = min(1000 * (2 ** self.reconnect_attempts), 30000)  # 最大30秒
            self.reconnect_timer.start(delay)
            self.reconnect_attempts += 1
    
    def reconnect(self):
        """再接続実行"""
        self.reconnect_timer.stop()
        asyncio.create_task(self.connect())


class MetricCard(QFrame):
    """
    メトリクス表示カード
    Real-timeデータ表示用のウィジェット
    """
    
    def __init__(self, metric: DashboardMetric):
        super().__init__()
        self.metric = metric
        self.init_ui()
        
    def init_ui(self):
        """UI初期化"""
        self.setFrameStyle(QFrame.Shape.StyledPanel)
        self.setMinimumSize(200, 120)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(15, 15, 15, 15)
        
        # メトリクス名
        self.name_label = QLabel(self.metric.name)
        self.name_label.setFont(QFont("Yu Gothic UI", 10, QFont.Weight.Bold))
        self.name_label.setStyleSheet("color: #6c757d;")
        
        # メトリクス値
        self.value_label = QLabel(str(self.metric.value))
        self.value_label.setFont(QFont("Yu Gothic UI", 18, QFont.Weight.Bold))
        self.value_label.setStyleSheet("color: #212529;")
        
        # 単位とトレンド
        trend_layout = QHBoxLayout()
        
        if self.metric.unit:
            unit_label = QLabel(self.metric.unit)
            unit_label.setFont(QFont("Yu Gothic UI", 9))
            unit_label.setStyleSheet("color: #6c757d;")
            trend_layout.addWidget(unit_label)
        
        # トレンド表示
        if self.metric.trend != 0:
            trend_icon = "↗️" if self.metric.trend > 0 else "↘️"
            trend_text = f"{trend_icon} {abs(self.metric.trend):.1%}"
            trend_label = QLabel(trend_text)
            trend_label.setFont(QFont("Yu Gothic UI", 9))
            
            if self.metric.trend > 0:
                trend_label.setStyleSheet("color: #28a745;")  # 緑色
            else:
                trend_label.setStyleSheet("color: #dc3545;")  # 赤色
                
            trend_layout.addWidget(trend_label)
        
        trend_layout.addStretch()
        
        # ステータスインジケーター
        status_color = self.get_status_color()
        self.setStyleSheet(f"""
            MetricCard {{
                border-left: 4px solid {status_color};
                background-color: white;
                border-radius: 4px;
            }}
        """)
        
        layout.addWidget(self.name_label)
        layout.addWidget(self.value_label)
        layout.addLayout(trend_layout)
        layout.addStretch()
        
    def get_status_color(self) -> str:
        """ステータスに応じた色を取得"""
        status_colors = {
            "normal": "#28a745",
            "warning": "#ffc107", 
            "critical": "#dc3545"
        }
        return status_colors.get(self.metric.status, "#6c757d")
        
    def update_metric(self, metric: DashboardMetric):
        """メトリクス更新"""
        self.metric = metric
        
        # アニメーション付きで値更新
        self.animate_value_change()
        
        # UI要素更新
        self.name_label.setText(metric.name)
        self.value_label.setText(str(metric.value))
        
        # スタイル更新
        status_color = self.get_status_color()
        self.setStyleSheet(f"""
            MetricCard {{
                border-left: 4px solid {status_color};
                background-color: white;
                border-radius: 4px;
            }}
        """)
    
    def animate_value_change(self):
        """値変更時のアニメーション"""
        # フェードアニメーション
        self.animation = QPropertyAnimation(self, b"windowOpacity")
        self.animation.setDuration(300)
        self.animation.setStartValue(0.7)
        self.animation.setEndValue(1.0)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.animation.start()


class RealTimeLogViewer(QTextEdit):
    """
    Real-timeログビューア（強化版）
    WebSocketからのログストリーミング対応
    """
    
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.log_buffer = []
        self.max_log_lines = 1000
        self.auto_scroll = True
        
    def init_ui(self):
        """UI初期化"""
        self.setReadOnly(True)
        self.setFont(QFont("Consolas", 9))
        self.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e1e;
                color: #ffffff;
                border: 1px solid #3c3c3c;
                border-radius: 4px;
                padding: 8px;
            }
        """)
        
    def append_log_entry(self, timestamp: str, level: str, message: str, source: str = ""):
        """ログエントリ追加（Real-time対応）"""
        # ログレベルに応じた色設定
        level_colors = {
            "INFO": "#17a2b8",
            "SUCCESS": "#28a745",
            "WARNING": "#ffc107",
            "ERROR": "#dc3545",
            "DEBUG": "#6f42c1"
        }
        
        color = level_colors.get(level.upper(), "#ffffff")
        icon = self.get_level_icon(level)
        
        # HTMLフォーマット
        log_html = f"""
        <div style="margin-bottom: 4px;">
            <span style="color: #6c757d;">[{timestamp}]</span>
            <span style="color: {color}; font-weight: bold;">{icon} {level}</span>
            {f'<span style="color: #adb5bd;">({source})</span>' if source else ''}
            <span style="color: #ffffff;">{message}</span>
        </div>
        """
        
        # ログバッファに追加
        self.log_buffer.append(log_html)
        
        # バッファサイズ制限
        if len(self.log_buffer) > self.max_log_lines:
            self.log_buffer = self.log_buffer[-self.max_log_lines:]
            
        # UI更新
        self.setHtml(''.join(self.log_buffer))
        
        # 自動スクロール
        if self.auto_scroll:
            scrollbar = self.verticalScrollBar()
            scrollbar.setValue(scrollbar.maximum())
    
    def get_level_icon(self, level: str) -> str:
        """ログレベルアイコン取得"""
        icons = {
            "INFO": "ℹ️",
            "SUCCESS": "✅",
            "WARNING": "⚠️",
            "ERROR": "❌",
            "DEBUG": "🔍"
        }
        return icons.get(level.upper(), "📝")
    
    def toggle_auto_scroll(self, enabled: bool):
        """自動スクロール切り替え"""
        self.auto_scroll = enabled
    
    def clear_logs(self):
        """ログクリア"""
        self.log_buffer.clear()
        self.clear()


class InteractiveProgressDashboard(QWidget):
    """
    インタラクティブ進捗ダッシュボード
    26機能の実行状況をリアルタイム表示
    """
    
    def __init__(self):
        super().__init__()
        self.function_progress = {}  # 機能別進捗管理
        self.init_ui()
        
    def init_ui(self):
        """UI初期化"""
        layout = QVBoxLayout(self)
        
        # ヘッダー
        header_layout = QHBoxLayout()
        
        title_label = QLabel("実行状況ダッシュボード")
        title_label.setFont(QFont("Yu Gothic UI", 14, QFont.Weight.Bold))
        title_label.setStyleSheet("color: #0078d4;")
        
        # 全体進捗バー
        self.overall_progress = QProgressBar()
        self.overall_progress.setMaximumHeight(8)
        self.overall_progress.setTextVisible(False)
        self.overall_progress.setStyleSheet("""
            QProgressBar {
                border: none;
                background-color: #e9ecef;
                border-radius: 4px;
            }
            QProgressBar::chunk {
                background-color: #0078d4;
                border-radius: 4px;
            }
        """)
        
        header_layout.addWidget(title_label)
        header_layout.addStretch()
        header_layout.addWidget(QLabel("全体進捗:"))
        header_layout.addWidget(self.overall_progress)
        
        layout.addLayout(header_layout)
        
        # 機能別進捗表示エリア
        scroll_area = QScrollArea()
        scroll_widget = QWidget()
        self.progress_layout = QGridLayout(scroll_widget)
        
        # 26機能の進捗カードを作成
        self.create_function_progress_cards()
        
        scroll_area.setWidget(scroll_widget)
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        
        layout.addWidget(scroll_area)
        
    def create_function_progress_cards(self):
        """26機能の進捗カード作成"""
        functions = [
            # 定期レポート
            ("daily_report", "📅 日次レポート"),
            ("weekly_report", "📊 週次レポート"),
            ("monthly_report", "📈 月次レポート"),
            ("yearly_report", "📆 年次レポート"),
            ("test_execution", "🧪 テスト実行"),
            ("latest_daily", "📋 最新日次レポート"),
            
            # 分析レポート
            ("license_analysis", "📊 ライセンス分析"),
            ("usage_analysis", "📈 使用状況分析"),
            ("performance_analysis", "⚡ パフォーマンス分析"),
            ("security_analysis", "🛡️ セキュリティ分析"),
            ("permission_audit", "🔍 権限監査"),
            
            # Entra ID管理
            ("user_list", "👥 ユーザー一覧"),
            ("mfa_status", "🔐 MFA状況"),
            ("conditional_access", "🛡️ 条件付きアクセス"),
            ("signin_logs", "📝 サインインログ"),
            
            # Exchange Online
            ("mailbox_management", "📧 メールボックス管理"),
            ("mail_flow_analysis", "🔄 メールフロー分析"),
            ("spam_protection", "🛡️ スパム対策分析"),
            ("mail_delivery", "📬 配信分析"),
            
            # Teams管理
            ("teams_usage", "💬 Teams使用状況"),
            ("teams_settings", "⚙️ Teams設定分析"),
            ("meeting_quality", "📹 会議品質分析"),
            ("teams_apps", "📱 アプリ分析"),
            
            # OneDrive管理
            ("storage_analysis", "💾 ストレージ分析"),
            ("sharing_analysis", "🤝 共有分析"),
            ("sync_error", "🔄 同期エラー分析"),
            ("external_sharing", "🌐 外部共有分析"),
        ]
        
        for i, (func_id, func_name) in enumerate(functions):
            row = i // 4
            col = i % 4
            
            card = self.create_progress_card(func_id, func_name)
            self.progress_layout.addWidget(card, row, col)
            
    def create_progress_card(self, func_id: str, func_name: str) -> QFrame:
        """進捗カード作成"""
        card = QFrame()
        card.setFrameStyle(QFrame.Shape.StyledPanel)
        card.setMinimumSize(200, 80)
        card.setStyleSheet("""
            QFrame {
                background-color: white;
                border: 1px solid #dee2e6;
                border-radius: 4px;
                padding: 8px;
            }
        """)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 8, 10, 8)
        
        # 機能名
        name_label = QLabel(func_name)
        name_label.setFont(QFont("Yu Gothic UI", 9, QFont.Weight.Bold))
        name_label.setStyleSheet("color: #212529;")
        
        # 進捗バー
        progress_bar = QProgressBar()
        progress_bar.setMaximumHeight(6)
        progress_bar.setTextVisible(False)
        progress_bar.setValue(0)
        progress_bar.setStyleSheet("""
            QProgressBar {
                border: none;
                background-color: #f8f9fa;
                border-radius: 3px;
            }
            QProgressBar::chunk {
                background-color: #28a745;
                border-radius: 3px;
            }
        """)
        
        # ステータスラベル
        status_label = QLabel("待機中")
        status_label.setFont(QFont("Yu Gothic UI", 8))
        status_label.setStyleSheet("color: #6c757d;")
        
        layout.addWidget(name_label)
        layout.addWidget(progress_bar)
        layout.addWidget(status_label)
        
        # 進捗管理辞書に登録
        self.function_progress[func_id] = {
            "card": card,
            "progress_bar": progress_bar,
            "status_label": status_label,
            "progress": 0,
            "status": "待機中"
        }
        
        return card
        
    def update_function_progress(self, func_id: str, progress: int, status: str):
        """機能進捗更新"""
        if func_id in self.function_progress:
            func_data = self.function_progress[func_id]
            
            # 進捗バー更新
            func_data["progress_bar"].setValue(progress)
            func_data["status_label"].setText(status)
            func_data["progress"] = progress
            func_data["status"] = status
            
            # ステータスに応じてスタイル変更
            if status == "実行中":
                func_data["progress_bar"].setStyleSheet("""
                    QProgressBar {
                        border: none;
                        background-color: #f8f9fa;
                        border-radius: 3px;
                    }
                    QProgressBar::chunk {
                        background-color: #0078d4;
                        border-radius: 3px;
                    }
                """)
            elif status == "完了":
                func_data["progress_bar"].setStyleSheet("""
                    QProgressBar {
                        border: none;
                        background-color: #f8f9fa;
                        border-radius: 3px;
                    }
                    QProgressBar::chunk {
                        background-color: #28a745;
                        border-radius: 3px;
                    }
                """)
            elif status == "エラー":
                func_data["progress_bar"].setStyleSheet("""
                    QProgressBar {
                        border: none;
                        background-color: #f8f9fa;
                        border-radius: 3px;
                    }
                    QProgressBar::chunk {
                        background-color: #dc3545;
                        border-radius: 3px;
                    }
                """)
            
            # 全体進捗更新
            self.update_overall_progress()
    
    def update_overall_progress(self):
        """全体進捗更新"""
        if not self.function_progress:
            return
            
        total_progress = sum(data["progress"] for data in self.function_progress.values())
        avg_progress = total_progress // len(self.function_progress)
        
        self.overall_progress.setValue(avg_progress)


class RealTimeDashboard(QWidget):
    """
    Real-time Dashboard メインウィジェット
    WebSocket統合 + 26機能統合Dashboard
    """
    
    # シグナル定義
    metric_updated = pyqtSignal(str, DashboardMetric)  # metric_id, metric
    function_progress_updated = pyqtSignal(str, int, str)  # func_id, progress, status
    log_entry_added = pyqtSignal(str, str, str, str)  # timestamp, level, message, source
    
    def __init__(self, websocket_url: str = "ws://localhost:8000/ws"):
        super().__init__()
        self.websocket_url = websocket_url
        self.metrics = {}
        self.init_ui()
        self.init_websocket()
        
    def init_ui(self):
        """UI初期化"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # ヘッダー
        header = self.create_header()
        layout.addWidget(header)
        
        # メインスプリッター（左右分割）
        main_splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # 左側: メトリクスとチャート
        left_widget = self.create_left_panel()
        main_splitter.addWidget(left_widget)
        
        # 右側: ログとプログレス
        right_widget = self.create_right_panel()
        main_splitter.addWidget(right_widget)
        
        # スプリッター比率設定（左:右 = 6:4）
        main_splitter.setSizes([600, 400])
        layout.addWidget(main_splitter)
        
    def create_header(self) -> QWidget:
        """ヘッダー作成"""
        header = QFrame()
        header.setFrameStyle(QFrame.Shape.StyledPanel)
        header.setMaximumHeight(60)
        
        layout = QHBoxLayout(header)
        
        # タイトル
        title = QLabel("Microsoft 365 Real-time Dashboard")
        title.setFont(QFont("Yu Gothic UI", 16, QFont.Weight.Bold))
        title.setStyleSheet("color: #0078d4;")
        
        # 接続ステータス
        self.connection_status = QLabel("⚫ 未接続")
        self.connection_status.setFont(QFont("Yu Gothic UI", 10))
        self.connection_status.setStyleSheet("color: #dc3545;")
        
        # 最終更新時間
        self.last_update = QLabel("最終更新: --")
        self.last_update.setFont(QFont("Yu Gothic UI", 9))
        self.last_update.setStyleSheet("color: #6c757d;")
        
        layout.addWidget(title)
        layout.addStretch()
        layout.addWidget(self.last_update)
        layout.addWidget(self.connection_status)
        
        return header
        
    def create_left_panel(self) -> QWidget:
        """左パネル作成（メトリクス・チャート）"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # メトリクスカード表示エリア
        metrics_group = QGroupBox("システムメトリクス")
        metrics_layout = QGridLayout(metrics_group)
        
        # 初期メトリクス作成
        initial_metrics = [
            DashboardMetric("active_users", "アクティブユーザー", 0, "人", 0.05, "normal"),
            DashboardMetric("license_usage", "ライセンス使用率", 0, "%", -0.02, "warning"),
            DashboardMetric("security_alerts", "セキュリティアラート", 0, "件", 0.1, "critical"),
            DashboardMetric("system_performance", "システムパフォーマンス", 0, "%", 0.03, "normal"),
        ]
        
        for i, metric in enumerate(initial_metrics):
            card = MetricCard(metric)
            self.metrics[metric.id] = {"card": card, "metric": metric}
            
            row = i // 2
            col = i % 2
            metrics_layout.addWidget(card, row, col)
        
        layout.addWidget(metrics_group)
        
        # チャート表示エリア
        chart_group = QGroupBox("使用状況チャート")
        chart_layout = QVBoxLayout(chart_group)
        
        # 簡易チャート（実装）
        self.chart_view = self.create_sample_chart()
        chart_layout.addWidget(self.chart_view)
        
        layout.addWidget(chart_group)
        
        return widget
        
    def create_right_panel(self) -> QWidget:
        """右パネル作成（ログ・プログレス）"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # タブウィジェット
        tab_widget = QTabWidget()
        
        # 実行進捗タブ
        self.progress_dashboard = InteractiveProgressDashboard()
        tab_widget.addTab(self.progress_dashboard, "🚀 実行進捗")
        
        # リアルタイムログタブ
        self.log_viewer = RealTimeLogViewer()
        tab_widget.addTab(self.log_viewer, "📝 リアルタイムログ")
        
        layout.addWidget(tab_widget)
        
        return widget
        
    def create_sample_chart(self) -> QChartView:
        """サンプルチャート作成"""
        # ライン系列作成
        series = QLineSeries()
        series.setName("ユーザーアクティビティ")
        
        # サンプルデータ
        for i in range(24):
            series.append(i, 50 + (i * 2) % 100)
        
        # チャート作成
        chart = QChart()
        chart.addSeries(series)
        chart.setTitle("過去24時間のユーザーアクティビティ")
        chart.setAnimationOptions(QChart.AnimationOption.SeriesAnimations)
        
        # 軸設定
        axis_x = QValueAxis()
        axis_x.setRange(0, 23)
        axis_x.setTitleText("時間")
        
        axis_y = QValueAxis()
        axis_y.setRange(0, 150)
        axis_y.setTitleText("アクティブユーザー数")
        
        chart.addAxis(axis_x, Qt.AlignmentFlag.AlignBottom)
        chart.addAxis(axis_y, Qt.AlignmentFlag.AlignLeft)
        series.attachAxis(axis_x)
        series.attachAxis(axis_y)
        
        # チャートビュー作成
        chart_view = QChartView(chart)
        chart_view.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        return chart_view
        
    def init_websocket(self):
        """WebSocket初期化"""
        self.ws_client = WebSocketClient(self.websocket_url)
        
        # シグナル接続
        self.ws_client.connection_status_changed.connect(self.on_connection_status_changed)
        self.ws_client.data_received.connect(self.on_data_received)
        self.ws_client.error_occurred.connect(self.on_error_occurred)
        
        # 内部シグナル接続
        self.metric_updated.connect(self.update_metric_card)
        self.function_progress_updated.connect(self.progress_dashboard.update_function_progress)
        self.log_entry_added.connect(self.log_viewer.append_log_entry)
        
        # 接続開始
        asyncio.create_task(self.ws_client.connect())
        
    @pyqtSlot(str)
    def on_connection_status_changed(self, status: str):
        """接続ステータス変更時の処理"""
        status_icons = {
            "disconnected": "⚫",
            "connecting": "🟡", 
            "connected": "🟢",
            "reconnecting": "🟠",
            "error": "🔴"
        }
        
        status_colors = {
            "disconnected": "#6c757d",
            "connecting": "#ffc107",
            "connected": "#28a745", 
            "reconnecting": "#fd7e14",
            "error": "#dc3545"
        }
        
        icon = status_icons.get(status, "⚫")
        color = status_colors.get(status, "#6c757d")
        
        self.connection_status.setText(f"{icon} {status.upper()}")
        self.connection_status.setStyleSheet(f"color: {color};")
        
    @pyqtSlot(str, dict)
    def on_data_received(self, data_type: str, data: dict):
        """データ受信時の処理"""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.last_update.setText(f"最終更新: {current_time}")
        
        if data_type == "metric_update":
            # メトリクス更新
            metric_id = data.get("metric_id")
            if metric_id:
                metric = DashboardMetric(
                    id=metric_id,
                    name=data.get("name", ""),
                    value=data.get("value", 0),
                    unit=data.get("unit", ""),
                    trend=data.get("trend", 0.0),
                    status=data.get("status", "normal"),
                    last_updated=datetime.now()
                )
                self.metric_updated.emit(metric_id, metric)
                
        elif data_type == "function_progress":
            # 機能進捗更新
            func_id = data.get("function_id")
            progress = data.get("progress", 0)
            status = data.get("status", "待機中")
            
            if func_id:
                self.function_progress_updated.emit(func_id, progress, status)
                
        elif data_type == "log_entry":
            # ログエントリ追加
            timestamp = data.get("timestamp", current_time)
            level = data.get("level", "INFO")
            message = data.get("message", "")
            source = data.get("source", "")
            
            self.log_entry_added.emit(timestamp, level, message, source)
            
    @pyqtSlot(str)
    def on_error_occurred(self, error_message: str):
        """エラー発生時の処理"""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.log_entry_added.emit(current_time, "ERROR", f"WebSocket Error: {error_message}", "Dashboard")
        
    @pyqtSlot(str, DashboardMetric)
    def update_metric_card(self, metric_id: str, metric: DashboardMetric):
        """メトリクスカード更新"""
        if metric_id in self.metrics:
            self.metrics[metric_id]["card"].update_metric(metric)
            self.metrics[metric_id]["metric"] = metric
    
    def simulate_real_time_data(self):
        """リアルタイムデータシミュレーション（開発・テスト用）"""
        import random
        
        # メトリクス更新シミュレーション
        for metric_id in self.metrics.keys():
            current_metric = self.metrics[metric_id]["metric"]
            
            # ランダムな値変更
            if metric_id == "active_users":
                new_value = random.randint(150, 300)
            elif metric_id == "license_usage":
                new_value = random.randint(60, 90)
            elif metric_id == "security_alerts":
                new_value = random.randint(0, 5)
            else:
                new_value = random.randint(80, 100)
            
            updated_metric = DashboardMetric(
                id=current_metric.id,
                name=current_metric.name,
                value=new_value,
                unit=current_metric.unit,
                trend=random.uniform(-0.1, 0.1),
                status=random.choice(["normal", "warning", "critical"]),
                last_updated=datetime.now()
            )
            
            self.metric_updated.emit(metric_id, updated_metric)
        
        # 機能進捗シミュレーション
        functions = ["daily_report", "user_list", "license_analysis", "teams_usage"]
        for func_id in functions:
            progress = random.randint(0, 100)
            if progress < 20:
                status = "待機中"
            elif progress < 100:
                status = "実行中"
            else:
                status = "完了"
                
            self.function_progress_updated.emit(func_id, progress, status)
        
        # ログエントリシミュレーション
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        levels = ["INFO", "SUCCESS", "WARNING", "ERROR"]
        messages = [
            "ユーザーアクティビティを更新しました",
            "ライセンス使用率を取得しました", 
            "セキュリティアラートを検出しました",
            "システム監視を実行中です"
        ]
        
        level = random.choice(levels)
        message = random.choice(messages)
        self.log_entry_added.emit(current_time, level, message, "System")


if __name__ == "__main__":
    from PyQt6.QtWidgets import QApplication
    
    app = QApplication(sys.argv)
    
    # メインダッシュボード作成
    dashboard = RealTimeDashboard()
    dashboard.setWindowTitle("Microsoft 365 Real-time Dashboard")
    dashboard.resize(1200, 800)
    dashboard.show()
    
    # データシミュレーション開始
    timer = QTimer()
    timer.timeout.connect(dashboard.simulate_real_time_data)
    timer.start(3000)  # 3秒間隔
    
    sys.exit(app.exec())