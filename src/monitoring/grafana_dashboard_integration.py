#!/usr/bin/env python3
"""
Grafana Dashboard Integration - CTO技術監督評価承認対応
Microsoft 365 Management Tools - Dashboard品質向上

Features:
- Grafana API Python統合
- Dashboard自動生成・管理
- Context7技術仕様準拠
- Real-time監視ダッシュボード
- Enterprise運用品質

Author: Operations Manager - CTO技術監督評価承認対応
Version: 1.0.0 CTO-APPROVED
Date: 2025-07-19
"""

import asyncio
import json
import logging
import requests
from typing import Dict, List, Optional, Any, Union
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from pathlib import Path
import uuid
import base64

try:
    import aiohttp
    from jinja2 import Template, Environment, FileSystemLoader
except ImportError as e:
    print(f"⚠️ Optional dependencies not available: {e}")
    print("Install with: pip install aiohttp jinja2")

# Configure logging for enterprise monitoring
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/microsoft365-grafana.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


@dataclass
class GrafanaDashboardConfig:
    """Grafana Dashboard Configuration"""
    title: str
    uid: str
    tags: List[str] = field(default_factory=list)
    description: str = ""
    refresh: str = "30s"
    time_from: str = "now-1h"
    time_to: str = "now"
    timezone: str = "browser"
    editable: bool = True
    graph_tooltip: str = "shared_crosshair"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to Grafana dashboard JSON format"""
        return {
            "title": self.title,
            "uid": self.uid,
            "tags": self.tags,
            "description": self.description,
            "refresh": self.refresh,
            "time": {
                "from": self.time_from,
                "to": self.time_to
            },
            "timezone": self.timezone,
            "editable": self.editable,
            "graphTooltip": 1 if self.graph_tooltip == "shared_crosshair" else 0
        }


@dataclass
class GrafanaPanel:
    """Grafana Panel Configuration"""
    id: int
    title: str
    type: str
    x: int = 0
    y: int = 0
    w: int = 12
    h: int = 8
    datasource: str = "prometheus"
    targets: List[Dict[str, Any]] = field(default_factory=list)
    options: Dict[str, Any] = field(default_factory=dict)
    field_config: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to Grafana panel JSON format"""
        return {
            "id": self.id,
            "title": self.title,
            "type": self.type,
            "gridPos": {
                "x": self.x,
                "y": self.y,
                "w": self.w,
                "h": self.h
            },
            "datasource": {"type": "prometheus", "uid": self.datasource},
            "targets": self.targets,
            "options": self.options,
            "fieldConfig": self.field_config
        }


class GrafanaAPIClient:
    """
    Grafana API Client for Dashboard Management
    Context7技術仕様準拠・Enterprise品質
    """
    
    def __init__(self, 
                 grafana_url: str,
                 api_key: str = None,
                 username: str = None,
                 password: str = None,
                 timeout: int = 30):
        """
        Initialize Grafana API Client
        
        Args:
            grafana_url: Grafana instance URL
            api_key: API key for authentication
            username: Username for basic auth
            password: Password for basic auth
            timeout: Request timeout in seconds
        """
        self.grafana_url = grafana_url.rstrip('/')
        self.api_key = api_key
        self.username = username
        self.password = password
        self.timeout = timeout
        
        # Setup authentication headers
        self.headers = {
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        
        if api_key:
            self.headers["Authorization"] = f"Bearer {api_key}"
        elif username and password:
            # Basic auth
            credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
            self.headers["Authorization"] = f"Basic {credentials}"
        
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        
        logger.info(f"🔧 Grafana API Client initialized: {grafana_url}")
    
    async def test_connection(self) -> Dict[str, Any]:
        """Test Grafana API connection"""
        try:
            response = self.session.get(
                f"{self.grafana_url}/api/health",
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                health_data = response.json()
                logger.info("✅ Grafana connection successful")
                return {
                    "status": "success",
                    "data": health_data,
                    "timestamp": datetime.utcnow().isoformat()
                }
            else:
                logger.error(f"❌ Grafana connection failed: {response.status_code}")
                return {
                    "status": "error",
                    "error": f"HTTP {response.status_code}",
                    "timestamp": datetime.utcnow().isoformat()
                }
                
        except Exception as e:
            logger.error(f"❌ Grafana connection error: {e}")
            return {
                "status": "error",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def get_datasources(self) -> List[Dict[str, Any]]:
        """Get all datasources"""
        try:
            response = self.session.get(
                f"{self.grafana_url}/api/datasources",
                timeout=self.timeout
            )
            response.raise_for_status()
            
            datasources = response.json()
            logger.info(f"📊 Retrieved {len(datasources)} datasources")
            return datasources
            
        except Exception as e:
            logger.error(f"Failed to get datasources: {e}")
            return []
    
    async def create_datasource(self, datasource_config: Dict[str, Any]) -> Dict[str, Any]:
        """Create new datasource"""
        try:
            response = self.session.post(
                f"{self.grafana_url}/api/datasources",
                json=datasource_config,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"✅ Datasource created: {result.get('name')}")
                return {"status": "success", "data": result}
            else:
                error_msg = response.text
                logger.error(f"❌ Failed to create datasource: {error_msg}")
                return {"status": "error", "error": error_msg}
                
        except Exception as e:
            logger.error(f"Datasource creation error: {e}")
            return {"status": "error", "error": str(e)}
    
    async def get_dashboards(self) -> List[Dict[str, Any]]:
        """Get all dashboards"""
        try:
            response = self.session.get(
                f"{self.grafana_url}/api/search",
                timeout=self.timeout
            )
            response.raise_for_status()
            
            dashboards = response.json()
            logger.info(f"📊 Retrieved {len(dashboards)} dashboards")
            return dashboards
            
        except Exception as e:
            logger.error(f"Failed to get dashboards: {e}")
            return []
    
    async def get_dashboard(self, uid: str) -> Optional[Dict[str, Any]]:
        """Get dashboard by UID"""
        try:
            response = self.session.get(
                f"{self.grafana_url}/api/dashboards/uid/{uid}",
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                dashboard = response.json()
                logger.info(f"📊 Retrieved dashboard: {dashboard['dashboard']['title']}")
                return dashboard
            elif response.status_code == 404:
                logger.warning(f"Dashboard not found: {uid}")
                return None
            else:
                response.raise_for_status()
                
        except Exception as e:
            logger.error(f"Failed to get dashboard {uid}: {e}")
            return None
    
    async def create_dashboard(self, dashboard_config: Dict[str, Any]) -> Dict[str, Any]:
        """Create or update dashboard"""
        try:
            payload = {
                "dashboard": dashboard_config,
                "overwrite": True,
                "message": f"Created/Updated via Microsoft 365 Management Tools"
            }
            
            response = self.session.post(
                f"{self.grafana_url}/api/dashboards/db",
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"✅ Dashboard created: {dashboard_config['title']}")
                return {"status": "success", "data": result}
            else:
                error_msg = response.text
                logger.error(f"❌ Failed to create dashboard: {error_msg}")
                return {"status": "error", "error": error_msg}
                
        except Exception as e:
            logger.error(f"Dashboard creation error: {e}")
            return {"status": "error", "error": str(e)}
    
    async def delete_dashboard(self, uid: str) -> Dict[str, Any]:
        """Delete dashboard by UID"""
        try:
            response = self.session.delete(
                f"{self.grafana_url}/api/dashboards/uid/{uid}",
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                logger.info(f"✅ Dashboard deleted: {uid}")
                return {"status": "success", "message": "Dashboard deleted"}
            else:
                error_msg = response.text
                logger.error(f"❌ Failed to delete dashboard: {error_msg}")
                return {"status": "error", "error": error_msg}
                
        except Exception as e:
            logger.error(f"Dashboard deletion error: {e}")
            return {"status": "error", "error": str(e)}


class Microsoft365GrafanaDashboard:
    """
    Microsoft 365 Grafana Dashboard Generator
    CTO技術監督評価承認レベル品質
    """
    
    def __init__(self, grafana_client: GrafanaAPIClient):
        self.grafana_client = grafana_client
        self.dashboard_templates = self._load_dashboard_templates()
        
        logger.info("🎯 Microsoft 365 Grafana Dashboard Generator initialized")
    
    def _load_dashboard_templates(self) -> Dict[str, str]:
        """Load dashboard templates"""
        templates = {
            "overview": self._get_overview_template(),
            "performance": self._get_performance_template(),
            "security": self._get_security_template(),
            "users": self._get_users_template(),
            "teams": self._get_teams_template(),
            "onedrive": self._get_onedrive_template()
        }
        return templates
    
    def _get_overview_template(self) -> str:
        """Overview dashboard template"""
        return """
        {
          "title": "Microsoft 365 - Overview Dashboard",
          "tags": ["microsoft365", "overview", "enterprise"],
          "refresh": "30s",
          "panels": [
            {
              "id": 1,
              "title": "System Health Status",
              "type": "stat",
              "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
              "targets": [
                {
                  "expr": "microsoft365_management_system_health_status",
                  "refId": "A"
                }
              ],
              "fieldConfig": {
                "defaults": {
                  "color": {"mode": "thresholds"},
                  "thresholds": {
                    "steps": [
                      {"color": "green", "value": null},
                      {"color": "red", "value": 80}
                    ]
                  }
                }
              }
            },
            {
              "id": 2,
              "title": "Active Users",
              "type": "stat",
              "gridPos": {"x": 6, "y": 0, "w": 6, "h": 4},
              "targets": [
                {
                  "expr": "microsoft365_management_active_users_total",
                  "refId": "A"
                }
              ]
            },
            {
              "id": 3,
              "title": "API Request Rate",
              "type": "graph",
              "gridPos": {"x": 0, "y": 4, "w": 12, "h": 8},
              "targets": [
                {
                  "expr": "rate(microsoft365_management_graph_api_requests_total[5m])",
                  "refId": "A",
                  "legendFormat": "{{operation}} ({{service}})"
                }
              ]
            }
          ]
        }
        """
    
    def _get_performance_template(self) -> str:
        """Performance dashboard template"""
        return """
        {
          "title": "Microsoft 365 - Performance Dashboard",
          "tags": ["microsoft365", "performance", "monitoring"],
          "refresh": "15s",
          "panels": [
            {
              "id": 1,
              "title": "API Response Time",
              "type": "graph",
              "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
              "targets": [
                {
                  "expr": "histogram_quantile(0.95, microsoft365_management_graph_api_duration_seconds_bucket)",
                  "refId": "A",
                  "legendFormat": "95th percentile"
                },
                {
                  "expr": "histogram_quantile(0.50, microsoft365_management_graph_api_duration_seconds_bucket)",
                  "refId": "B",
                  "legendFormat": "50th percentile"
                }
              ]
            },
            {
              "id": 2,
              "title": "System Resources",
              "type": "graph",
              "gridPos": {"x": 0, "y": 8, "w": 6, "h": 8},
              "targets": [
                {
                  "expr": "microsoft365_management_system_cpu_percent",
                  "refId": "A",
                  "legendFormat": "CPU %"
                },
                {
                  "expr": "microsoft365_management_system_memory_percent",
                  "refId": "B",
                  "legendFormat": "Memory %"
                }
              ]
            }
          ]
        }
        """
    
    def _get_security_template(self) -> str:
        """Security dashboard template"""
        return """
        {
          "title": "Microsoft 365 - Security Dashboard",
          "tags": ["microsoft365", "security", "compliance"],
          "refresh": "1m",
          "panels": [
            {
              "id": 1,
              "title": "Security Incidents",
              "type": "stat",
              "gridPos": {"x": 0, "y": 0, "w": 4, "h": 4},
              "targets": [
                {
                  "expr": "microsoft365_management_security_incidents_total",
                  "refId": "A"
                }
              ],
              "fieldConfig": {
                "defaults": {
                  "color": {"mode": "thresholds"},
                  "thresholds": {
                    "steps": [
                      {"color": "green", "value": null},
                      {"color": "yellow", "value": 1},
                      {"color": "red", "value": 5}
                    ]
                  }
                }
              }
            },
            {
              "id": 2,
              "title": "MFA Compliance",
              "type": "stat",
              "gridPos": {"x": 4, "y": 0, "w": 4, "h": 4},
              "targets": [
                {
                  "expr": "microsoft365_management_mfa_compliance_percent",
                  "refId": "A"
                }
              ],
              "fieldConfig": {
                "defaults": {
                  "unit": "percent",
                  "min": 0,
                  "max": 100
                }
              }
            }
          ]
        }
        """
    
    def _get_users_template(self) -> str:
        """Users dashboard template"""
        return """
        {
          "title": "Microsoft 365 - Users Dashboard",
          "tags": ["microsoft365", "users", "identity"],
          "refresh": "5m",
          "panels": [
            {
              "id": 1,
              "title": "User Activities",
              "type": "graph",
              "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
              "targets": [
                {
                  "expr": "rate(microsoft365_management_user_activities_total[5m])",
                  "refId": "A",
                  "legendFormat": "{{activity_type}} ({{service}})"
                }
              ]
            },
            {
              "id": 2,
              "title": "License Usage",
              "type": "piechart",
              "gridPos": {"x": 0, "y": 8, "w": 6, "h": 8},
              "targets": [
                {
                  "expr": "microsoft365_management_license_usage_current",
                  "refId": "A",
                  "legendFormat": "{{license_type}}"
                }
              ]
            }
          ]
        }
        """
    
    def _get_teams_template(self) -> str:
        """Teams dashboard template"""
        return """
        {
          "title": "Microsoft 365 - Teams Dashboard",
          "tags": ["microsoft365", "teams", "collaboration"],
          "refresh": "2m",
          "panels": [
            {
              "id": 1,
              "title": "Teams Activity",
              "type": "graph",
              "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
              "targets": [
                {
                  "expr": "microsoft365_management_teams_activity_total",
                  "refId": "A",
                  "legendFormat": "{{activity_type}}"
                }
              ]
            },
            {
              "id": 2,
              "title": "Meeting Quality",
              "type": "stat",
              "gridPos": {"x": 0, "y": 8, "w": 6, "h": 4},
              "targets": [
                {
                  "expr": "avg(microsoft365_management_teams_meeting_quality_score)",
                  "refId": "A"
                }
              ]
            }
          ]
        }
        """
    
    def _get_onedrive_template(self) -> str:
        """OneDrive dashboard template"""
        return """
        {
          "title": "Microsoft 365 - OneDrive Dashboard",
          "tags": ["microsoft365", "onedrive", "storage"],
          "refresh": "5m",
          "panels": [
            {
              "id": 1,
              "title": "Storage Usage",
              "type": "graph",
              "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
              "targets": [
                {
                  "expr": "microsoft365_management_onedrive_storage_usage_bytes",
                  "refId": "A",
                  "legendFormat": "Used Storage"
                },
                {
                  "expr": "microsoft365_management_onedrive_storage_quota_bytes",
                  "refId": "B",
                  "legendFormat": "Total Quota"
                }
              ]
            },
            {
              "id": 2,
              "title": "Sync Status",
              "type": "stat",
              "gridPos": {"x": 0, "y": 8, "w": 6, "h": 4},
              "targets": [
                {
                  "expr": "microsoft365_management_onedrive_sync_success_rate",
                  "refId": "A"
                }
              ]
            }
          ]
        }
        """
    
    async def create_prometheus_datasource(self, 
                                         name: str = "Microsoft365-Prometheus",
                                         url: str = "http://localhost:9090") -> Dict[str, Any]:
        """Create Prometheus datasource for Microsoft 365 metrics"""
        datasource_config = {
            "name": name,
            "type": "prometheus",
            "url": url,
            "access": "proxy",
            "isDefault": True,
            "jsonData": {
                "httpMethod": "POST",
                "manageAlerts": True,
                "alertmanagerUid": ""
            }
        }
        
        return await self.grafana_client.create_datasource(datasource_config)
    
    async def create_overview_dashboard(self) -> Dict[str, Any]:
        """Create Microsoft 365 overview dashboard"""
        dashboard_config = {
            "id": None,
            "uid": "microsoft365-overview",
            "title": "Microsoft 365 - Enterprise Overview",
            "tags": ["microsoft365", "overview", "enterprise"],
            "description": "Microsoft 365 Management Tools - Enterprise Overview Dashboard",
            "timezone": "browser",
            "refresh": "30s",
            "schemaVersion": 39,
            "version": 1,
            "time": {
                "from": "now-1h",
                "to": "now"
            },
            "panels": [
                {
                    "id": 1,
                    "title": "System Health Overview",
                    "type": "stat",
                    "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
                    "targets": [
                        {
                            "expr": "microsoft365_enterprise_system_health_status",
                            "refId": "A",
                            "format": "time_series"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "mode": "absolute",
                                "steps": [
                                    {"color": "green", "value": None},
                                    {"color": "yellow", "value": 1},
                                    {"color": "red", "value": 3}
                                ]
                            },
                            "mappings": [
                                {"options": {"0": {"text": "Healthy"}}, "type": "value"},
                                {"options": {"1": {"text": "Warning"}}, "type": "value"},
                                {"options": {"2": {"text": "Critical"}}, "type": "value"}
                            ]
                        }
                    },
                    "options": {
                        "colorMode": "background",
                        "orientation": "horizontal",
                        "reduceOptions": {
                            "values": False,
                            "calcs": ["lastNotNull"],
                            "fields": ""
                        }
                    }
                },
                {
                    "id": 2,
                    "title": "Active Users",
                    "type": "stat",
                    "gridPos": {"x": 6, "y": 0, "w": 6, "h": 4},
                    "targets": [
                        {
                            "expr": "microsoft365_enterprise_active_users_total",
                            "refId": "A"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"},
                            "unit": "short"
                        }
                    }
                },
                {
                    "id": 3,
                    "title": "API Request Rate",
                    "type": "timeseries",
                    "gridPos": {"x": 0, "y": 4, "w": 12, "h": 8},
                    "targets": [
                        {
                            "expr": "rate(microsoft365_enterprise_graph_api_requests_total[5m])",
                            "refId": "A",
                            "legendFormat": "{{operation}} ({{service}})"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"},
                            "unit": "reqps"
                        }
                    }
                },
                {
                    "id": 4,
                    "title": "SLA Availability",
                    "type": "gauge",
                    "gridPos": {"x": 0, "y": 12, "w": 6, "h": 6},
                    "targets": [
                        {
                            "expr": "microsoft365_enterprise_sla_availability",
                            "refId": "A"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "min": 0,
                            "max": 100,
                            "unit": "percent",
                            "thresholds": {
                                "steps": [
                                    {"color": "red", "value": None},
                                    {"color": "yellow", "value": 99},
                                    {"color": "green", "value": 99.9}
                                ]
                            }
                        }
                    },
                    "options": {
                        "orientation": "auto",
                        "reduceOptions": {
                            "values": False,
                            "calcs": ["lastNotNull"],
                            "fields": ""
                        },
                        "showThresholdLabels": False,
                        "showThresholdMarkers": True
                    }
                },
                {
                    "id": 5,
                    "title": "WebSocket Connections",
                    "type": "stat",
                    "gridPos": {"x": 6, "y": 12, "w": 6, "h": 6},
                    "targets": [
                        {
                            "expr": "microsoft365_enterprise_websocket_connections_active",
                            "refId": "A"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"},
                            "unit": "short"
                        }
                    }
                }
            ]
        }
        
        return await self.grafana_client.create_dashboard(dashboard_config)
    
    async def create_performance_dashboard(self) -> Dict[str, Any]:
        """Create Microsoft 365 performance dashboard"""
        dashboard_config = {
            "id": None,
            "uid": "microsoft365-performance",
            "title": "Microsoft 365 - Performance Monitoring",
            "tags": ["microsoft365", "performance", "monitoring"],
            "description": "Microsoft 365 Management Tools - Performance Dashboard",
            "timezone": "browser",
            "refresh": "15s",
            "schemaVersion": 39,
            "version": 1,
            "time": {
                "from": "now-30m",
                "to": "now"
            },
            "panels": [
                {
                    "id": 1,
                    "title": "API Response Time Distribution",
                    "type": "timeseries",
                    "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
                    "targets": [
                        {
                            "expr": "histogram_quantile(0.95, rate(microsoft365_enterprise_graph_api_duration_seconds_bucket[5m]))",
                            "refId": "A",
                            "legendFormat": "95th percentile"
                        },
                        {
                            "expr": "histogram_quantile(0.50, rate(microsoft365_enterprise_graph_api_duration_seconds_bucket[5m]))",
                            "refId": "B",
                            "legendFormat": "50th percentile"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"},
                            "unit": "s"
                        }
                    }
                },
                {
                    "id": 2,
                    "title": "System Resources",
                    "type": "timeseries",
                    "gridPos": {"x": 0, "y": 8, "w": 6, "h": 8},
                    "targets": [
                        {
                            "expr": "microsoft365_enterprise_system_cpu_percent",
                            "refId": "A",
                            "legendFormat": "CPU %"
                        },
                        {
                            "expr": "microsoft365_enterprise_system_memory_percent",
                            "refId": "B",
                            "legendFormat": "Memory %"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"},
                            "unit": "percent",
                            "min": 0,
                            "max": 100
                        }
                    }
                },
                {
                    "id": 3,
                    "title": "Report Generation Performance",
                    "type": "timeseries",
                    "gridPos": {"x": 6, "y": 8, "w": 6, "h": 8},
                    "targets": [
                        {
                            "expr": "histogram_quantile(0.95, rate(microsoft365_enterprise_report_generation_duration_seconds_bucket[10m]))",
                            "refId": "A",
                            "legendFormat": "{{report_type}} ({{format}})"
                        }
                    ],
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"},
                            "unit": "s"
                        }
                    }
                }
            ]
        }
        
        return await self.grafana_client.create_dashboard(dashboard_config)
    
    async def create_all_dashboards(self) -> Dict[str, Any]:
        """Create all Microsoft 365 dashboards"""
        results = {}
        
        try:
            # Create Prometheus datasource first
            logger.info("🔧 Creating Prometheus datasource...")
            ds_result = await self.create_prometheus_datasource()
            results["datasource"] = ds_result
            
            # Create dashboards
            logger.info("📊 Creating Overview dashboard...")
            overview_result = await self.create_overview_dashboard()
            results["overview"] = overview_result
            
            logger.info("📊 Creating Performance dashboard...")
            performance_result = await self.create_performance_dashboard()
            results["performance"] = performance_result
            
            # Success summary
            success_count = sum(1 for r in results.values() if r.get("status") == "success")
            total_count = len(results)
            
            logger.info(f"✅ Dashboard creation completed: {success_count}/{total_count} successful")
            
            return {
                "status": "completed",
                "success_count": success_count,
                "total_count": total_count,
                "results": results,
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Dashboard creation failed: {e}")
            return {
                "status": "error",
                "error": str(e),
                "results": results,
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def update_dashboard_variables(self, uid: str, variables: Dict[str, str]) -> Dict[str, Any]:
        """Update dashboard with template variables"""
        try:
            # Get existing dashboard
            dashboard = await self.grafana_client.get_dashboard(uid)
            if not dashboard:
                return {"status": "error", "error": "Dashboard not found"}
            
            # Update dashboard with variables
            dashboard_config = dashboard["dashboard"]
            
            # Add template variables
            dashboard_config["templating"] = {
                "list": [
                    {
                        "name": name,
                        "type": "textbox",
                        "current": {"value": value},
                        "options": [{"value": value, "text": value}]
                    }
                    for name, value in variables.items()
                ]
            }
            
            # Update dashboard
            return await self.grafana_client.create_dashboard(dashboard_config)
            
        except Exception as e:
            logger.error(f"Failed to update dashboard variables: {e}")
            return {"status": "error", "error": str(e)}


# Global integration instance
grafana_integration = Microsoft365GrafanaDashboard(
    GrafanaAPIClient("http://localhost:3000", api_key="")
)


async def setup_microsoft365_grafana_monitoring(
    grafana_url: str = "http://localhost:3000",
    api_key: str = None,
    username: str = "admin",
    password: str = "admin"
) -> Dict[str, Any]:
    """Setup complete Microsoft 365 Grafana monitoring"""
    
    try:
        # Initialize Grafana client
        grafana_client = GrafanaAPIClient(
            grafana_url=grafana_url,
            api_key=api_key,
            username=username,
            password=password
        )
        
        # Test connection
        logger.info("🔗 Testing Grafana connection...")
        connection_test = await grafana_client.test_connection()
        if connection_test["status"] != "success":
            return connection_test
        
        # Initialize dashboard generator
        dashboard_generator = Microsoft365GrafanaDashboard(grafana_client)
        
        # Create all dashboards
        logger.info("📊 Setting up Microsoft 365 dashboards...")
        setup_result = await dashboard_generator.create_all_dashboards()
        
        return setup_result
        
    except Exception as e:
        logger.error(f"❌ Grafana monitoring setup failed: {e}")
        return {
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


if __name__ == "__main__":
    print("🔧 Microsoft 365 Grafana Dashboard Integration - CTO技術監督評価承認")
    print("Setting up enterprise monitoring dashboards...")
    
    async def main():
        result = await setup_microsoft365_grafana_monitoring()
        print(f"Setup result: {json.dumps(result, indent=2)}")
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⚠️ Setup stopped by user")
    except Exception as e:
        print(f"❌ Setup error: {e}")