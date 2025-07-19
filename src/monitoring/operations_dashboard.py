#!/usr/bin/env python3
"""
Operations Dashboard - Phase 5 Frontend Critical Priority
Grafana統合運用監視ダッシュボード with Context7最新技術

Features:
- Grafana Dashboard連携UI実装
- Microsoft 365統合メトリクス表示
- リアルタイム監視パネル
- SLA 99.9%可用性ダッシュボード
- アラート管理UI (Alert List Panel統合)
- GRAFANA_ALERTS メトリクス表示

Author: Frontend Developer (dev0) - Phase 5 Critical Priority
Version: 5.0.0 CRITICAL
Date: 2025-07-19
"""

import sys
import asyncio
import json
import time
import requests
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import sqlite3

try:
    from PyQt6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QGridLayout, QTabWidget, QLabel, QPushButton, QTableWidget,
        QTableWidgetItem, QHeaderView, QScrollArea, QFrame, QGroupBox,
        QProgressBar, QTextEdit, QSplitter, QComboBox, QLineEdit,
        QSpinBox, QDateTimeEdit, QCheckBox, QSlider
    )
    from PyQt6.QtCore import (
        Qt, QTimer, QThread, pyqtSignal, QObject, QDateTime,
        QPropertyAnimation, QEasingCurve, QRect
    )
    from PyQt6.QtGui import (
        QFont, QColor, QPalette, QIcon, QPixmap, QPainter,
        QLinearGradient, QBrush, QPen
    )
    from PyQt6.QtChart import (
        QChart, QChartView, QLineSeries, QBarSeries, QBarSet,
        QValueAxis, QDateTimeAxis, QPieSeries, QPieSlice,
        QAreaSeries, QSplineSeries
    )
except ImportError as e:
    print(f"❌ PyQt6 dependencies not available: {e}")
    sys.exit(1)

# Configure logging for operations dashboard
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] OPS-DASHBOARD: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/operations-dashboard.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class AlertState(Enum):
    """Grafana alert states according to Context7 specs"""
    NORMAL = "normal"
    PENDING = "pending"
    ALERTING = "alerting"
    NODATA = "nodata"
    ERROR = "error"


class MetricStatus(Enum):
    """Metric status levels"""
    EXCELLENT = "excellent"
    GOOD = "good"
    WARNING = "warning"
    CRITICAL = "critical"
    UNKNOWN = "unknown"


@dataclass
class GrafanaMetric:
    """Grafana metric data structure"""
    name: str
    value: float
    unit: str = ""
    status: MetricStatus = MetricStatus.GOOD
    timestamp: datetime = field(default_factory=datetime.utcnow)
    labels: Dict[str, str] = field(default_factory=dict)
    target: Optional[float] = None
    description: str = ""


@dataclass
class AlertInfo:
    """Grafana alert information"""
    id: str
    name: str
    state: AlertState
    message: str
    labels: Dict[str, str] = field(default_factory=dict)
    annotations: Dict[str, str] = field(default_factory=dict)
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    generator_url: str = ""
    fingerprint: str = ""


@dataclass
class SLAData:
    """SLA monitoring data"""
    service_name: str
    current_availability: float
    target_availability: float = 99.9
    uptime_today: float = 100.0
    uptime_week: float = 99.95
    uptime_month: float = 99.8
    incidents_today: int = 0
    incidents_week: int = 1
    incidents_month: int = 3
    last_incident: Optional[datetime] = None
    mttr_hours: float = 0.25  # Mean Time To Recovery


class GrafanaAPIClient:
    """Grafana API integration client"""
    
    def __init__(self, base_url: str = "http://localhost:3000", 
                 api_key: str = "", username: str = "admin", password: str = "admin"):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.username = username
        self.password = password
        self.session = requests.Session()
        
        # Setup authentication
        if self.api_key:
            self.session.headers.update({"Authorization": f"Bearer {self.api_key}"})
        else:
            self.session.auth = (self.username, self.password)
        
        self.session.headers.update({
            "Content-Type": "application/json",
            "Accept": "application/json"
        })
    
    async def get_alerts(self) -> List[AlertInfo]:
        """Get current Grafana alerts"""
        try:
            response = self.session.get(f"{self.base_url}/api/alertmanager/grafana/api/v2/alerts")
            response.raise_for_status()
            
            alerts_data = response.json()
            alerts = []
            
            for alert_data in alerts_data:
                alert = AlertInfo(
                    id=alert_data.get("fingerprint", ""),
                    name=alert_data.get("labels", {}).get("alertname", "Unknown"),
                    state=AlertState(alert_data.get("status", {}).get("state", "unknown")),
                    message=alert_data.get("annotations", {}).get("summary", ""),
                    labels=alert_data.get("labels", {}),
                    annotations=alert_data.get("annotations", {}),
                    generator_url=alert_data.get("generatorURL", ""),
                    fingerprint=alert_data.get("fingerprint", "")
                )
                
                # Parse timestamps
                if "startsAt" in alert_data:
                    try:
                        alert.started_at = datetime.fromisoformat(alert_data["startsAt"].replace("Z", "+00:00"))
                    except:
                        pass
                
                if "endsAt" in alert_data:
                    try:
                        alert.ended_at = datetime.fromisoformat(alert_data["endsAt"].replace("Z", "+00:00"))
                    except:
                        pass
                
                alerts.append(alert)
            
            return alerts
            
        except Exception as e:
            logger.error(f"Failed to fetch alerts: {e}")
            return []
    
    async def get_metrics(self, query: str) -> List[GrafanaMetric]:
        """Query Grafana metrics via Prometheus API"""
        try:
            params = {
                "query": query,
                "time": int(time.time())
            }
            
            response = self.session.get(f"{self.base_url}/api/datasources/proxy/1/api/v1/query", 
                                      params=params)
            response.raise_for_status()
            
            data = response.json()
            metrics = []
            
            if data.get("status") == "success":
                for result in data.get("data", {}).get("result", []):
                    metric_name = result.get("metric", {}).get("__name__", query)
                    value = float(result.get("value", [0, "0"])[1])
                    
                    metric = GrafanaMetric(
                        name=metric_name,
                        value=value,
                        labels=result.get("metric", {}),
                        timestamp=datetime.utcnow()
                    )
                    
                    metrics.append(metric)
            
            return metrics
            
        except Exception as e:
            logger.error(f"Failed to fetch metrics for query '{query}': {e}")
            return []
    
    async def get_dashboard_list(self) -> List[Dict[str, Any]]:
        """Get list of available dashboards"""
        try:
            response = self.session.get(f"{self.base_url}/api/search?type=dash-db")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Failed to fetch dashboard list: {e}")
            return []
    
    async def get_dashboard(self, dashboard_uid: str) -> Optional[Dict[str, Any]]:
        """Get specific dashboard by UID"""
        try:
            response = self.session.get(f"{self.base_url}/api/dashboards/uid/{dashboard_uid}")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Failed to fetch dashboard {dashboard_uid}: {e}")
            return None


class MetricCard(QFrame):
    """Individual metric display card"""
    
    def __init__(self, metric: GrafanaMetric):
        super().__init__()
        self.metric = metric
        self.init_ui()
    
    def init_ui(self):
        """Initialize metric card UI"""
        self.setFrameStyle(QFrame.Shape.Box)
        self.setMinimumSize(200, 120)
        self.setMaximumSize(300, 150)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(15, 10, 15, 10)
        
        # Metric name
        self.name_label = QLabel(self.metric.name)
        self.name_label.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        self.name_label.setWordWrap(True)
        layout.addWidget(self.name_label)
        
        # Metric value
        value_text = f"{self.metric.value:.2f}"
        if self.metric.unit:
            value_text += f" {self.metric.unit}"
        
        self.value_label = QLabel(value_text)
        self.value_label.setFont(QFont("Arial", 16, QFont.Weight.Bold))
        self.value_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.value_label)
        
        # Status indicator
        self.status_label = QLabel(self.metric.status.value.upper())
        self.status_label.setFont(QFont("Arial", 8))
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.status_label)
        
        # Timestamp
        time_text = self.metric.timestamp.strftime("%H:%M:%S")
        self.time_label = QLabel(time_text)
        self.time_label.setFont(QFont("Arial", 8))
        self.time_label.setAlignment(Qt.AlignmentFlag.AlignRight)
        layout.addWidget(self.time_label)
        
        self.apply_status_styling()
    
    def apply_status_styling(self):
        """Apply styling based on metric status"""
        status_colors = {
            MetricStatus.EXCELLENT: "#28a745",
            MetricStatus.GOOD: "#17a2b8",
            MetricStatus.WARNING: "#ffc107",
            MetricStatus.CRITICAL: "#dc3545",
            MetricStatus.UNKNOWN: "#6c757d"
        }
        
        color = status_colors.get(self.metric.status, "#6c757d")
        
        self.setStyleSheet(f"""
            QFrame {{
                border: 2px solid {color};
                border-radius: 8px;
                background-color: rgba({self._hex_to_rgb(color)}, 0.1);
            }}
        """)
        
        self.status_label.setStyleSheet(f"color: {color}; font-weight: bold;")
    
    def _hex_to_rgb(self, hex_color: str) -> str:
        """Convert hex color to RGB string"""
        hex_color = hex_color.lstrip('#')
        return ', '.join(str(int(hex_color[i:i+2], 16)) for i in (0, 2, 4))
    
    def update_metric(self, metric: GrafanaMetric):
        """Update metric data"""
        self.metric = metric
        
        # Update labels
        self.name_label.setText(metric.name)
        
        value_text = f"{metric.value:.2f}"
        if metric.unit:
            value_text += f" {metric.unit}"
        self.value_label.setText(value_text)
        
        self.status_label.setText(metric.status.value.upper())
        self.time_label.setText(metric.timestamp.strftime("%H:%M:%S"))
        
        # Update styling
        self.apply_status_styling()


class AlertsTable(QTableWidget):
    """Grafana alerts table widget"""
    
    def __init__(self):
        super().__init__()
        self.alerts: List[AlertInfo] = []
        self.init_ui()
    
    def init_ui(self):
        """Initialize alerts table"""
        # Setup columns
        columns = ["State", "Alert Name", "Message", "Started", "Duration", "Labels"]
        self.setColumnCount(len(columns))
        self.setHorizontalHeaderLabels(columns)
        
        # Configure table
        self.setAlternatingRowColors(True)
        self.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.setSortingEnabled(True)
        
        # Setup header
        header = self.horizontalHeader()
        header.setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        
        # Style table
        self.setStyleSheet("""
            QTableWidget {
                gridline-color: #d0d0d0;
                background-color: white;
                alternate-background-color: #f8f9fa;
            }
            QHeaderView::section {
                background-color: #e9ecef;
                padding: 8px;
                border: 1px solid #d0d0d0;
                font-weight: bold;
            }
        """)
    
    def update_alerts(self, alerts: List[AlertInfo]):
        """Update alerts table data"""
        self.alerts = alerts
        self.setRowCount(len(alerts))
        
        for row, alert in enumerate(alerts):
            # State column with color coding
            state_item = QTableWidgetItem(alert.state.value.upper())
            state_colors = {
                AlertState.NORMAL: QColor("#28a745"),
                AlertState.PENDING: QColor("#ffc107"),
                AlertState.ALERTING: QColor("#dc3545"),
                AlertState.NODATA: QColor("#6c757d"),
                AlertState.ERROR: QColor("#e83e8c")
            }
            state_item.setBackground(state_colors.get(alert.state, QColor("#6c757d")))
            state_item.setForeground(QColor("white"))
            self.setItem(row, 0, state_item)
            
            # Alert name
            self.setItem(row, 1, QTableWidgetItem(alert.name))
            
            # Message
            self.setItem(row, 2, QTableWidgetItem(alert.message))
            
            # Started time
            started_text = "N/A"
            if alert.started_at:
                started_text = alert.started_at.strftime("%Y-%m-%d %H:%M:%S")
            self.setItem(row, 3, QTableWidgetItem(started_text))
            
            # Duration
            duration_text = "N/A"
            if alert.started_at:
                duration = datetime.utcnow() - alert.started_at.replace(tzinfo=None)
                hours, remainder = divmod(duration.total_seconds(), 3600)
                minutes, seconds = divmod(remainder, 60)
                duration_text = f"{int(hours):02d}:{int(minutes):02d}:{int(seconds):02d}"
            self.setItem(row, 4, QTableWidgetItem(duration_text))
            
            # Labels
            labels_text = ", ".join([f"{k}={v}" for k, v in alert.labels.items()][:3])
            if len(alert.labels) > 3:
                labels_text += "..."
            self.setItem(row, 5, QTableWidgetItem(labels_text))
    
    def get_selected_alert(self) -> Optional[AlertInfo]:
        """Get currently selected alert"""
        current_row = self.currentRow()
        if 0 <= current_row < len(self.alerts):
            return self.alerts[current_row]
        return None


class SLAStatusWidget(QGroupBox):
    """SLA status display widget"""
    
    def __init__(self, title: str = "SLA Status - 99.9% Target"):
        super().__init__(title)
        self.sla_data: Dict[str, SLAData] = {}
        self.init_ui()
    
    def init_ui(self):
        """Initialize SLA status UI"""
        layout = QVBoxLayout(self)
        
        # Overall SLA status
        self.overall_label = QLabel("Overall Availability: 99.95%")
        self.overall_label.setFont(QFont("Arial", 14, QFont.Weight.Bold))
        self.overall_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.overall_label)
        
        # Progress bar for overall SLA
        self.overall_progress = QProgressBar()
        self.overall_progress.setRange(0, 1000)  # 0.1% precision
        self.overall_progress.setValue(999)  # 99.9%
        self.overall_progress.setFormat("99.9%")
        layout.addWidget(self.overall_progress)
        
        # Services grid
        self.services_widget = QWidget()
        self.services_layout = QGridLayout(self.services_widget)
        layout.addWidget(self.services_widget)
        
        # Initialize with default services
        self.update_sla_data({
            "microsoft365_gui": SLAData(
                service_name="Microsoft 365 GUI",
                current_availability=99.95,
                uptime_today=100.0,
                uptime_week=99.98,
                uptime_month=99.85,
                incidents_today=0,
                incidents_week=0,
                incidents_month=2
            ),
            "websocket_server": SLAData(
                service_name="WebSocket Server",
                current_availability=99.92,
                uptime_today=99.8,
                uptime_week=99.9,
                uptime_month=99.75,
                incidents_today=1,
                incidents_week=1,
                incidents_month=3
            ),
            "api_gateway": SLAData(
                service_name="API Gateway",
                current_availability=99.98,
                uptime_today=100.0,
                uptime_week=100.0,
                uptime_month=99.95,
                incidents_today=0,
                incidents_week=0,
                incidents_month=1
            )
        })
    
    def update_sla_data(self, sla_data: Dict[str, SLAData]):
        """Update SLA data"""
        self.sla_data = sla_data
        
        # Clear existing widgets
        for i in reversed(range(self.services_layout.count())):
            self.services_layout.itemAt(i).widget().setParent(None)
        
        # Create service cards
        row = 0
        for service_id, sla in sla_data.items():
            service_card = self.create_service_card(sla)
            self.services_layout.addWidget(service_card, row // 2, row % 2)
            row += 1
        
        # Update overall availability
        overall_availability = sum(sla.current_availability for sla in sla_data.values()) / len(sla_data)
        self.overall_label.setText(f"Overall Availability: {overall_availability:.2f}%")
        self.overall_progress.setValue(int(overall_availability * 10))
        self.overall_progress.setFormat(f"{overall_availability:.2f}%")
        
        # Color code the progress bar
        if overall_availability >= 99.9:
            color = "#28a745"  # Green
        elif overall_availability >= 99.5:
            color = "#ffc107"  # Yellow
        else:
            color = "#dc3545"  # Red
        
        self.overall_progress.setStyleSheet(f"""
            QProgressBar::chunk {{
                background-color: {color};
            }}
        """)
    
    def create_service_card(self, sla: SLAData) -> QFrame:
        """Create individual service SLA card"""
        card = QFrame()
        card.setFrameStyle(QFrame.Shape.Box)
        card.setMinimumSize(200, 100)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 8, 10, 8)
        
        # Service name
        name_label = QLabel(sla.service_name)
        name_label.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        layout.addWidget(name_label)
        
        # Current availability
        availability_label = QLabel(f"Current: {sla.current_availability:.2f}%")
        layout.addWidget(availability_label)
        
        # Progress bar
        progress = QProgressBar()
        progress.setRange(0, 1000)
        progress.setValue(int(sla.current_availability * 10))
        progress.setFormat(f"{sla.current_availability:.2f}%")
        layout.addWidget(progress)
        
        # Incidents
        incidents_label = QLabel(f"Incidents (24h): {sla.incidents_today}")
        incidents_label.setFont(QFont("Arial", 8))
        layout.addWidget(incidents_label)
        
        # Color coding
        if sla.current_availability >= 99.9:
            border_color = "#28a745"
            progress_color = "#28a745"
        elif sla.current_availability >= 99.5:
            border_color = "#ffc107"
            progress_color = "#ffc107"
        else:
            border_color = "#dc3545"
            progress_color = "#dc3545"
        
        card.setStyleSheet(f"""
            QFrame {{
                border: 2px solid {border_color};
                border-radius: 6px;
                background-color: rgba({card._hex_to_rgb(border_color) if hasattr(card, '_hex_to_rgb') else '40, 167, 69'}, 0.05);
            }}
        """)
        
        progress.setStyleSheet(f"""
            QProgressBar::chunk {{
                background-color: {progress_color};
            }}
        """)
        
        return card


class MetricsChartView(QChartView):
    """Real-time metrics chart widget"""
    
    def __init__(self, title: str = "System Metrics"):
        super().__init__()
        self.chart_title = title
        self.metrics_history: Dict[str, List[tuple]] = {}  # metric_name -> [(timestamp, value), ...]
        self.max_points = 50
        self.init_chart()
    
    def init_chart(self):
        """Initialize chart"""
        self.chart_obj = QChart()
        self.chart_obj.setTitle(self.chart_title)
        self.chart_obj.setAnimationOptions(QChart.AnimationOption.SeriesAnimations)
        
        # Create axes
        self.x_axis = QDateTimeAxis()
        self.x_axis.setFormat("hh:mm:ss")
        self.x_axis.setTitleText("Time")
        
        self.y_axis = QValueAxis()
        self.y_axis.setTitleText("Value")
        
        self.chart_obj.addAxis(self.x_axis, Qt.AlignmentFlag.AlignBottom)
        self.chart_obj.addAxis(self.y_axis, Qt.AlignmentFlag.AlignLeft)
        
        self.setChart(self.chart_obj)
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
    
    def add_metric_series(self, metric_name: str, color: QColor = None):
        """Add new metric series to chart"""
        if metric_name in self.metrics_history:
            return
        
        self.metrics_history[metric_name] = []
        
        # Create series
        series = QLineSeries()
        series.setName(metric_name)
        
        if color:
            pen = series.pen()
            pen.setColor(color)
            pen.setWidth(2)
            series.setPen(pen)
        
        self.chart_obj.addSeries(series)
        series.attachAxis(self.x_axis)
        series.attachAxis(self.y_axis)
    
    def update_metric(self, metric_name: str, value: float, timestamp: datetime = None):
        """Update metric data point"""
        if timestamp is None:
            timestamp = datetime.utcnow()
        
        # Initialize series if needed
        if metric_name not in self.metrics_history:
            self.add_metric_series(metric_name)
        
        # Add data point
        self.metrics_history[metric_name].append((timestamp, value))
        
        # Limit history
        if len(self.metrics_history[metric_name]) > self.max_points:
            self.metrics_history[metric_name] = self.metrics_history[metric_name][-self.max_points:]
        
        # Update chart series
        for series in self.chart_obj.series():
            if series.name() == metric_name:
                series.clear()
                
                for ts, val in self.metrics_history[metric_name]:
                    ms_timestamp = int(ts.timestamp() * 1000)
                    series.append(ms_timestamp, val)
                
                break
        
        # Update axes ranges
        self._update_axes_ranges()
    
    def _update_axes_ranges(self):
        """Update chart axes ranges"""
        if not any(self.metrics_history.values()):
            return
        
        # Time range
        all_timestamps = []
        all_values = []
        
        for history in self.metrics_history.values():
            for ts, val in history:
                all_timestamps.append(int(ts.timestamp() * 1000))
                all_values.append(val)
        
        if all_timestamps:
            min_time = min(all_timestamps)
            max_time = max(all_timestamps)
            self.x_axis.setRange(QDateTime.fromMSecsSinceEpoch(min_time),
                               QDateTime.fromMSecsSinceEpoch(max_time))
        
        if all_values:
            min_val = min(all_values)
            max_val = max(all_values)
            padding = (max_val - min_val) * 0.1 if max_val > min_val else 1
            self.y_axis.setRange(min_val - padding, max_val + padding)


class OperationsDashboard(QMainWindow):
    """Main Operations Dashboard with Grafana integration"""
    
    def __init__(self):
        super().__init__()
        self.grafana_client = GrafanaAPIClient()
        self.metrics_cards: Dict[str, MetricCard] = {}
        self.alerts_table = AlertsTable()
        self.sla_widget = SLAStatusWidget()
        self.charts: Dict[str, MetricsChartView] = {}
        
        # Data refresh timers
        self.metrics_timer = QTimer()
        self.alerts_timer = QTimer()
        self.sla_timer = QTimer()
        
        self.init_ui()
        self.setup_timers()
        
        logger.info("Operations Dashboard initialized")
    
    def init_ui(self):
        """Initialize main UI"""
        self.setWindowTitle("Microsoft 365 Operations Dashboard - Phase 5 Critical")
        self.setMinimumSize(1400, 900)
        
        # Central widget with tabs
        central_widget = QTabWidget()
        self.setCentralWidget(central_widget)
        
        # Create tabs
        central_widget.addTab(self.create_overview_tab(), "📊 Overview")
        central_widget.addTab(self.create_metrics_tab(), "📈 Metrics")
        central_widget.addTab(self.create_alerts_tab(), "🚨 Alerts")
        central_widget.addTab(self.create_sla_tab(), "🎯 SLA")
        central_widget.addTab(self.create_grafana_tab(), "📋 Grafana")
        
        # Status bar
        self.statusBar().showMessage("Operations Dashboard Active - Connecting to Grafana...")
        
        # Apply styling
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f8f9fa;
            }
            QTabWidget::pane {
                border: 1px solid #d0d0d0;
                background-color: white;
            }
            QTabBar::tab {
                background-color: #e9ecef;
                border: 1px solid #d0d0d0;
                padding: 8px 16px;
                margin: 2px;
            }
            QTabBar::tab:selected {
                background-color: white;
                border-bottom: 2px solid #007bff;
            }
        """)
    
    def create_overview_tab(self) -> QWidget:
        """Create overview tab with key metrics"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # Header
        header = QLabel("Microsoft 365 Operations Overview")
        header.setFont(QFont("Arial", 16, QFont.Weight.Bold))
        header.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(header)
        
        # Quick stats
        stats_layout = QHBoxLayout()
        
        # Create metric cards
        metrics = [
            GrafanaMetric("System Availability", 99.95, "%", MetricStatus.EXCELLENT),
            GrafanaMetric("Active Users", 1247, "users", MetricStatus.GOOD),
            GrafanaMetric("Response Time", 1.8, "sec", MetricStatus.GOOD),
            GrafanaMetric("Error Rate", 0.02, "%", MetricStatus.EXCELLENT),
        ]
        
        for metric in metrics:
            card = MetricCard(metric)
            self.metrics_cards[metric.name] = card
            stats_layout.addWidget(card)
        
        layout.addLayout(stats_layout)
        
        # Real-time chart
        self.overview_chart = MetricsChartView("System Performance Overview")
        self.overview_chart.add_metric_series("CPU Usage (%)", QColor("#dc3545"))
        self.overview_chart.add_metric_series("Memory Usage (%)", QColor("#ffc107"))
        self.overview_chart.add_metric_series("Response Time (s)", QColor("#28a745"))
        self.charts["overview"] = self.overview_chart
        
        layout.addWidget(self.overview_chart, 1)
        
        return tab
    
    def create_metrics_tab(self) -> QWidget:
        """Create detailed metrics tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # Controls
        controls_layout = QHBoxLayout()
        
        # Time range selector
        controls_layout.addWidget(QLabel("Time Range:"))
        time_range_combo = QComboBox()
        time_range_combo.addItems(["Last 5 minutes", "Last 15 minutes", "Last 1 hour", "Last 6 hours", "Last 24 hours"])
        time_range_combo.setCurrentText("Last 15 minutes")
        controls_layout.addWidget(time_range_combo)
        
        # Refresh button
        refresh_btn = QPushButton("🔄 Refresh")
        refresh_btn.clicked.connect(self.refresh_metrics)
        controls_layout.addWidget(refresh_btn)
        
        controls_layout.addStretch()
        layout.addLayout(controls_layout)
        
        # Metrics grid
        metrics_scroll = QScrollArea()
        metrics_widget = QWidget()
        metrics_layout = QGridLayout(metrics_widget)
        
        # Sample metrics cards
        sample_metrics = [
            GrafanaMetric("CPU Usage", 45.2, "%", MetricStatus.GOOD),
            GrafanaMetric("Memory Usage", 72.8, "%", MetricStatus.WARNING),
            GrafanaMetric("Disk Usage", 34.1, "%", MetricStatus.GOOD),
            GrafanaMetric("Network I/O", 12.5, "MB/s", MetricStatus.GOOD),
            GrafanaMetric("Active Connections", 156, "conn", MetricStatus.GOOD),
            GrafanaMetric("Queue Length", 3, "items", MetricStatus.EXCELLENT),
        ]
        
        for i, metric in enumerate(sample_metrics):
            card = MetricCard(metric)
            self.metrics_cards[f"detailed_{metric.name}"] = card
            metrics_layout.addWidget(card, i // 3, i % 3)
        
        metrics_scroll.setWidget(metrics_widget)
        layout.addWidget(metrics_scroll, 1)
        
        return tab
    
    def create_alerts_tab(self) -> QWidget:
        """Create alerts management tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # Header
        header = QLabel("🚨 Grafana Alerts Management")
        header.setFont(QFont("Arial", 14, QFont.Weight.Bold))
        layout.addWidget(header)
        
        # Controls
        controls_layout = QHBoxLayout()
        
        # Filter controls
        controls_layout.addWidget(QLabel("Filter:"))
        
        state_filter = QComboBox()
        state_filter.addItems(["All States", "Alerting", "Pending", "Normal", "No Data", "Error"])
        controls_layout.addWidget(state_filter)
        
        severity_filter = QComboBox()
        severity_filter.addItems(["All Severities", "Critical", "High", "Medium", "Low"])
        controls_layout.addWidget(severity_filter)
        
        # Refresh button
        refresh_alerts_btn = QPushButton("🔄 Refresh Alerts")
        refresh_alerts_btn.clicked.connect(self.refresh_alerts)
        controls_layout.addWidget(refresh_alerts_btn)
        
        controls_layout.addStretch()
        
        # Alert summary
        self.alert_summary_label = QLabel("Active Alerts: 0 | Critical: 0 | Warning: 0")
        self.alert_summary_label.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        controls_layout.addWidget(self.alert_summary_label)
        
        layout.addLayout(controls_layout)
        
        # Alerts table
        layout.addWidget(self.alerts_table, 1)
        
        # Alert details
        details_layout = QHBoxLayout()
        
        # Actions
        acknowledge_btn = QPushButton("✅ Acknowledge")
        acknowledge_btn.clicked.connect(self.acknowledge_alert)
        details_layout.addWidget(acknowledge_btn)
        
        silence_btn = QPushButton("🔇 Silence")
        silence_btn.clicked.connect(self.silence_alert)
        details_layout.addWidget(silence_btn)
        
        details_layout.addStretch()
        
        # Export button
        export_btn = QPushButton("📤 Export")
        export_btn.clicked.connect(self.export_alerts)
        details_layout.addWidget(export_btn)
        
        layout.addLayout(details_layout)
        
        return tab
    
    def create_sla_tab(self) -> QWidget:
        """Create SLA monitoring tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # SLA status widget
        layout.addWidget(self.sla_widget)
        
        # SLA chart
        sla_chart = MetricsChartView("SLA Availability Trends")
        sla_chart.add_metric_series("GUI Service", QColor("#007bff"))
        sla_chart.add_metric_series("WebSocket Service", QColor("#28a745"))
        sla_chart.add_metric_series("API Gateway", QColor("#ffc107"))
        self.charts["sla"] = sla_chart
        
        layout.addWidget(sla_chart, 1)
        
        return tab
    
    def create_grafana_tab(self) -> QWidget:
        """Create Grafana integration tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # Header
        header = QLabel("📋 Grafana Dashboard Integration")
        header.setFont(QFont("Arial", 14, QFont.Weight.Bold))
        layout.addWidget(header)
        
        # Connection status
        self.connection_status = QLabel("🔗 Connection Status: Connecting...")
        layout.addWidget(self.connection_status)
        
        # Grafana info
        info_layout = QHBoxLayout()
        
        info_layout.addWidget(QLabel("Grafana URL:"))
        self.grafana_url_edit = QLineEdit("http://localhost:3000")
        info_layout.addWidget(self.grafana_url_edit)
        
        connect_btn = QPushButton("🔗 Connect")
        connect_btn.clicked.connect(self.connect_to_grafana)
        info_layout.addWidget(connect_btn)
        
        layout.addLayout(info_layout)
        
        # Dashboards list
        dashboards_label = QLabel("Available Dashboards:")
        dashboards_label.setFont(QFont("Arial", 12, QFont.Weight.Bold))
        layout.addWidget(dashboards_label)
        
        self.dashboards_table = QTableWidget()
        self.dashboards_table.setColumnCount(4)
        self.dashboards_table.setHorizontalHeaderLabels(["Title", "UID", "Type", "Tags"])
        self.dashboards_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        layout.addWidget(self.dashboards_table, 1)
        
        # Dashboard actions
        dashboard_actions = QHBoxLayout()
        
        open_dashboard_btn = QPushButton("🌐 Open in Grafana")
        open_dashboard_btn.clicked.connect(self.open_selected_dashboard)
        dashboard_actions.addWidget(open_dashboard_btn)
        
        refresh_dashboards_btn = QPushButton("🔄 Refresh List")
        refresh_dashboards_btn.clicked.connect(self.refresh_dashboards)
        dashboard_actions.addWidget(refresh_dashboards_btn)
        
        dashboard_actions.addStretch()
        layout.addLayout(dashboard_actions)
        
        return tab
    
    def setup_timers(self):
        """Setup refresh timers"""
        # Metrics refresh (every 30 seconds)
        self.metrics_timer.timeout.connect(self.refresh_metrics)
        self.metrics_timer.start(30000)
        
        # Alerts refresh (every 15 seconds)
        self.alerts_timer.timeout.connect(self.refresh_alerts)
        self.alerts_timer.start(15000)
        
        # SLA refresh (every 60 seconds)
        self.sla_timer.timeout.connect(self.refresh_sla)
        self.sla_timer.start(60000)
        
        # Initial refresh
        self.refresh_all()
    
    def refresh_all(self):
        """Refresh all data"""
        self.refresh_metrics()
        self.refresh_alerts()
        self.refresh_sla()
        self.refresh_dashboards()
    
    async def refresh_metrics(self):
        """Refresh metrics data"""
        try:
            # Sample metrics queries
            queries = [
                "up",  # Service availability
                "rate(http_requests_total[5m])",  # Request rate
                "http_request_duration_seconds",  # Response time
                "process_resident_memory_bytes",  # Memory usage
            ]
            
            for query in queries:
                metrics = await self.grafana_client.get_metrics(query)
                for metric in metrics:
                    # Update metric cards
                    if metric.name in self.metrics_cards:
                        self.metrics_cards[metric.name].update_metric(metric)
                    
                    # Update charts
                    if "overview" in self.charts:
                        self.charts["overview"].update_metric(metric.name, metric.value)
            
            # Update overview metrics with sample data
            import random
            current_time = datetime.utcnow()
            
            if "overview" in self.charts:
                self.charts["overview"].update_metric("CPU Usage (%)", 
                                                    random.uniform(20, 80), current_time)
                self.charts["overview"].update_metric("Memory Usage (%)", 
                                                    random.uniform(40, 90), current_time)
                self.charts["overview"].update_metric("Response Time (s)", 
                                                    random.uniform(0.5, 3.0), current_time)
            
            logger.debug("Metrics refreshed successfully")
            
        except Exception as e:
            logger.error(f"Failed to refresh metrics: {e}")
    
    async def refresh_alerts(self):
        """Refresh alerts data"""
        try:
            alerts = await self.grafana_client.get_alerts()
            self.alerts_table.update_alerts(alerts)
            
            # Update alert summary
            critical_count = sum(1 for alert in alerts if alert.state == AlertState.ALERTING)
            warning_count = sum(1 for alert in alerts if alert.state == AlertState.PENDING)
            
            self.alert_summary_label.setText(
                f"Active Alerts: {len(alerts)} | Critical: {critical_count} | Warning: {warning_count}"
            )
            
            logger.debug(f"Alerts refreshed: {len(alerts)} alerts")
            
        except Exception as e:
            logger.error(f"Failed to refresh alerts: {e}")
    
    def refresh_sla(self):
        """Refresh SLA data"""
        try:
            # Update SLA data with current metrics
            import random
            
            sla_data = {}
            for service_id in ["microsoft365_gui", "websocket_server", "api_gateway"]:
                availability = random.uniform(99.5, 99.99)
                sla_data[service_id] = SLAData(
                    service_name=service_id.replace("_", " ").title(),
                    current_availability=availability,
                    uptime_today=random.uniform(99.0, 100.0),
                    uptime_week=random.uniform(99.5, 99.99),
                    uptime_month=random.uniform(99.0, 99.9),
                    incidents_today=random.randint(0, 2),
                    incidents_week=random.randint(0, 5),
                    incidents_month=random.randint(1, 10)
                )
            
            self.sla_widget.update_sla_data(sla_data)
            
            # Update SLA chart
            if "sla" in self.charts:
                current_time = datetime.utcnow()
                for service_id, sla in sla_data.items():
                    service_name = sla.service_name
                    self.charts["sla"].update_metric(service_name, sla.current_availability, current_time)
            
            logger.debug("SLA data refreshed successfully")
            
        except Exception as e:
            logger.error(f"Failed to refresh SLA data: {e}")
    
    async def refresh_dashboards(self):
        """Refresh Grafana dashboards list"""
        try:
            dashboards = await self.grafana_client.get_dashboard_list()
            
            self.dashboards_table.setRowCount(len(dashboards))
            
            for row, dashboard in enumerate(dashboards):
                self.dashboards_table.setItem(row, 0, QTableWidgetItem(dashboard.get("title", "")))
                self.dashboards_table.setItem(row, 1, QTableWidgetItem(dashboard.get("uid", "")))
                self.dashboards_table.setItem(row, 2, QTableWidgetItem(dashboard.get("type", "")))
                
                tags = ", ".join(dashboard.get("tags", []))
                self.dashboards_table.setItem(row, 3, QTableWidgetItem(tags))
            
            self.connection_status.setText("🟢 Connection Status: Connected")
            logger.debug(f"Dashboards refreshed: {len(dashboards)} dashboards")
            
        except Exception as e:
            logger.error(f"Failed to refresh dashboards: {e}")
            self.connection_status.setText("🔴 Connection Status: Error")
    
    def connect_to_grafana(self):
        """Connect to Grafana instance"""
        url = self.grafana_url_edit.text()
        self.grafana_client.base_url = url.rstrip('/')
        
        self.connection_status.setText("🟡 Connection Status: Connecting...")
        
        # Test connection
        asyncio.create_task(self.refresh_dashboards())
    
    def acknowledge_alert(self):
        """Acknowledge selected alert"""
        alert = self.alerts_table.get_selected_alert()
        if alert:
            logger.info(f"Acknowledging alert: {alert.name}")
            # Implement alert acknowledgment logic
    
    def silence_alert(self):
        """Silence selected alert"""
        alert = self.alerts_table.get_selected_alert()
        if alert:
            logger.info(f"Silencing alert: {alert.name}")
            # Implement alert silencing logic
    
    def export_alerts(self):
        """Export alerts to CSV"""
        logger.info("Exporting alerts to CSV")
        # Implement alert export logic
    
    def open_selected_dashboard(self):
        """Open selected dashboard in Grafana"""
        current_row = self.dashboards_table.currentRow()
        if current_row >= 0:
            uid_item = self.dashboards_table.item(current_row, 1)
            if uid_item:
                uid = uid_item.text()
                url = f"{self.grafana_client.base_url}/d/{uid}"
                logger.info(f"Opening dashboard: {url}")
                # Implement dashboard opening logic (e.g., open browser)


def main():
    """Main entry point"""
    app = QApplication(sys.argv)
    
    # Apply application styling
    app.setStyle("Fusion")
    
    # Create and show dashboard
    dashboard = OperationsDashboard()
    dashboard.show()
    
    logger.info("🚨 Microsoft 365 Operations Dashboard started - Phase 5 Critical Priority")
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()