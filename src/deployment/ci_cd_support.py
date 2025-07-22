"""
dev3 CI/CD統合技術支援モジュール
Pythonアプリケーションビルド・デプロイ最適化・環境変数管理・監視統合
"""

import os
import json
import yaml
import subprocess
import asyncio
from typing import Any, Dict, List, Optional, Union
from pathlib import Path
from dataclasses import dataclass, asdict
from enum import Enum
import tempfile
import shutil
from datetime import datetime

from ..core.config import settings
from ..core.logging_config import get_logger

logger = get_logger(__name__)

class DeploymentEnvironment(str, Enum):
    """デプロイメント環境"""
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TESTING = "testing"

class BuildType(str, Enum):
    """ビルドタイプ"""
    DOCKER = "docker"
    NATIVE = "native"
    LAMBDA = "lambda"
    KUBERNETES = "kubernetes"

@dataclass
class BuildConfiguration:
    """ビルド設定"""
    environment: DeploymentEnvironment
    build_type: BuildType
    python_version: str = "3.11"
    requirements_file: str = "requirements.txt"
    dockerfile: Optional[str] = None
    build_args: Dict[str, str] = None
    output_directory: str = "dist"
    include_patterns: List[str] = None
    exclude_patterns: List[str] = None
    
    def __post_init__(self):
        if self.build_args is None:
            self.build_args = {}
        if self.include_patterns is None:
            self.include_patterns = ["src/**", "Config/**", "Scripts/**"]
        if self.exclude_patterns is None:
            self.exclude_patterns = ["**/__pycache__", "**/.pytest_cache", "**/test_*", "**/*.pyc"]

@dataclass
class DeploymentConfiguration:
    """デプロイメント設定"""
    environment: DeploymentEnvironment
    target_platform: str  # "docker", "kubernetes", "ec2", "lambda"
    health_check_url: Optional[str] = None
    environment_variables: Dict[str, str] = None
    secrets: Dict[str, str] = None
    scaling_config: Dict[str, Any] = None
    monitoring_config: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.environment_variables is None:
            self.environment_variables = {}
        if self.secrets is None:
            self.secrets = {}
        if self.scaling_config is None:
            self.scaling_config = {"min_instances": 1, "max_instances": 5}
        if self.monitoring_config is None:
            self.monitoring_config = {"enabled": True, "metrics_port": 9090}

class EnvironmentManager:
    """環境変数・設定管理"""
    
    def __init__(self):
        self.base_dir = Path(settings.base_dir)
        self.config_dir = self.base_dir / "Config"
        self.deployment_dir = self.base_dir / "deployment"
        self.deployment_dir.mkdir(exist_ok=True)
        
        # 環境別設定ファイル
        self.env_configs = {
            DeploymentEnvironment.DEVELOPMENT: self.config_dir / "appsettings.development.json",
            DeploymentEnvironment.STAGING: self.config_dir / "appsettings.staging.json", 
            DeploymentEnvironment.PRODUCTION: self.config_dir / "appsettings.production.json",
            DeploymentEnvironment.TESTING: self.config_dir / "appsettings.testing.json"
        }
    
    def load_environment_config(self, environment: DeploymentEnvironment) -> Dict[str, Any]:
        """環境別設定読み込み"""
        try:
            # ベース設定読み込み
            base_config_path = self.config_dir / "appsettings.json"
            base_config = {}
            
            if base_config_path.exists():
                with open(base_config_path, 'r', encoding='utf-8') as f:
                    base_config = json.load(f)
            
            # 環境別設定読み込み
            env_config_path = self.env_configs.get(environment)
            env_config = {}
            
            if env_config_path and env_config_path.exists():
                with open(env_config_path, 'r', encoding='utf-8') as f:
                    env_config = json.load(f)
            
            # 設定マージ
            merged_config = self._merge_configs(base_config, env_config)
            
            # 環境変数オーバーライド
            merged_config = self._apply_environment_overrides(merged_config)
            
            return merged_config
            
        except Exception as e:
            logger.error(f"Failed to load environment config for {environment}: {e}")
            return {}
    
    def _merge_configs(self, base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
        """設定マージ"""
        result = base.copy()
        
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_configs(result[key], value)
            else:
                result[key] = value
        
        return result
    
    def _apply_environment_overrides(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """環境変数オーバーライド適用"""
        # 環境変数プレフィックス
        prefix = "M365TOOLS_"
        
        for env_var, value in os.environ.items():
            if env_var.startswith(prefix):
                # 設定キーに変換 (M365TOOLS_DATABASE__HOST -> database.host)
                config_key = env_var[len(prefix):].lower().replace("__", ".")
                
                # ネストした設定に適用
                self._set_nested_config(config, config_key, value)
        
        return config
    
    def _set_nested_config(self, config: Dict[str, Any], key_path: str, value: str):
        """ネストした設定値設定"""
        keys = key_path.split(".")
        current = config
        
        for key in keys[:-1]:
            if key not in current:
                current[key] = {}
            current = current[key]
        
        # 型変換
        final_key = keys[-1]
        if value.lower() in ("true", "false"):
            current[final_key] = value.lower() == "true"
        elif value.isdigit():
            current[final_key] = int(value)
        else:
            current[final_key] = value
    
    def generate_environment_file(self, environment: DeploymentEnvironment, output_path: Path):
        """環境設定ファイル生成"""
        config = self.load_environment_config(environment)
        
        # .env ファイル生成
        env_content = []
        env_content.append(f"# Generated environment file for {environment.value}")
        env_content.append(f"# Generated at: {datetime.utcnow().isoformat()}")
        env_content.append("")
        
        # 基本環境変数
        env_content.append("# Application Configuration")
        env_content.append(f"ENVIRONMENT={environment.value}")
        env_content.append(f"PYTHONPATH=/app/src")
        env_content.append("")
        
        # 設定から環境変数生成
        env_vars = self._config_to_env_vars(config)
        for env_var, value in env_vars.items():
            env_content.append(f"{env_var}={value}")
        
        # ファイル書き込み
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("\n".join(env_content))
        
        logger.info(f"Generated environment file: {output_path}")
    
    def _config_to_env_vars(self, config: Dict[str, Any], prefix: str = "M365TOOLS") -> Dict[str, str]:
        """設定を環境変数形式に変換"""
        env_vars = {}
        
        def flatten_config(obj: Any, path: str = ""):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    new_path = f"{path}__{key.upper()}" if path else key.upper()
                    flatten_config(value, new_path)
            elif isinstance(obj, (list, tuple)):
                # リストは JSON文字列として格納
                env_vars[f"{prefix}_{path}"] = json.dumps(obj)
            else:
                env_vars[f"{prefix}_{path}"] = str(obj)
        
        flatten_config(config)
        return env_vars

class DockerBuilder:
    """Docker ビルド支援"""
    
    def __init__(self):
        self.base_dir = Path(settings.base_dir)
        
    def generate_dockerfile(self, config: BuildConfiguration) -> str:
        """Dockerfile 生成"""
        
        if config.dockerfile and Path(config.dockerfile).exists():
            # 既存のDockerfileを使用
            with open(config.dockerfile, 'r', encoding='utf-8') as f:
                return f.read()
        
        # 標準Dockerfile生成
        dockerfile_content = f"""
# Generated Dockerfile for Microsoft 365 Management Tools
FROM python:{config.python_version}-slim

# システム依存関係
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    && rm -rf /var/lib/apt/lists/*

# PowerShell インストール (Linux)
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \\
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" > /etc/apt/sources.list.d/microsoft.list \\
    && apt-get update \\
    && apt-get install -y powershell \\
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリ設定
WORKDIR /app

# 依存関係ファイルコピー
COPY {config.requirements_file} .
COPY pyproject.toml .

# Python依存関係インストール
RUN pip install --no-cache-dir -r {config.requirements_file}

# アプリケーションファイルコピー
COPY src/ src/
COPY Config/ Config/
COPY Scripts/ Scripts/
COPY Templates/ Templates/

# 環境変数設定
ENV PYTHONPATH=/app/src
ENV ENVIRONMENT={config.environment.value}

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8000/api/health || exit 1

# ポート公開
EXPOSE 8000

# 実行コマンド
CMD ["python", "-m", "uvicorn", "src.main_fastapi:app", "--host", "0.0.0.0", "--port", "8000"]
"""
        
        return dockerfile_content.strip()
    
    def generate_docker_compose(self, config: DeploymentConfiguration) -> str:
        """Docker Compose ファイル生成"""
        
        compose_config = {
            "version": "3.8",
            "services": {
                "m365-tools": {
                    "build": {
                        "context": ".",
                        "dockerfile": "Dockerfile"
                    },
                    "ports": ["8000:8000"],
                    "environment": [
                        f"ENVIRONMENT={config.environment.value}"
                    ],
                    "volumes": [
                        "./Config:/app/Config:ro",
                        "./Logs:/app/Logs",
                        "./Reports:/app/Reports"
                    ],
                    "restart": "unless-stopped",
                    "healthcheck": {
                        "test": ["CMD", "curl", "-f", "http://localhost:8000/api/health"],
                        "interval": "30s",
                        "timeout": "10s",
                        "retries": 3,
                        "start_period": "40s"
                    }
                }
            }
        }
        
        # Redis サービス追加（必要に応じて）
        if config.environment != DeploymentEnvironment.TESTING:
            compose_config["services"]["redis"] = {
                "image": "redis:7-alpine",
                "ports": ["6379:6379"],
                "volumes": ["redis_data:/data"],
                "restart": "unless-stopped"
            }
            compose_config["volumes"] = {"redis_data": {}}
            
            # Redis環境変数追加
            compose_config["services"]["m365-tools"]["environment"].append(
                "M365TOOLS_REDIS__URL=redis://redis:6379"
            )
            compose_config["services"]["m365-tools"]["depends_on"] = ["redis"]
        
        # 環境変数追加
        for key, value in config.environment_variables.items():
            compose_config["services"]["m365-tools"]["environment"].append(f"{key}={value}")
        
        return yaml.dump(compose_config, default_flow_style=False, indent=2)
    
    async def build_docker_image(self, config: BuildConfiguration, image_tag: str) -> bool:
        """Dockerイメージビルド"""
        try:
            # Dockerfile生成
            dockerfile_content = self.generate_dockerfile(config)
            dockerfile_path = self.base_dir / "Dockerfile"
            
            with open(dockerfile_path, 'w', encoding='utf-8') as f:
                f.write(dockerfile_content)
            
            # ビルドコマンド構築
            build_command = [
                "docker", "build",
                "-t", image_tag,
                "-f", str(dockerfile_path)
            ]
            
            # ビルド引数追加
            for arg_name, arg_value in config.build_args.items():
                build_command.extend(["--build-arg", f"{arg_name}={arg_value}"])
            
            build_command.append(str(self.base_dir))
            
            # ビルド実行
            logger.info(f"Building Docker image: {image_tag}")
            result = await self._run_command(build_command)
            
            if result.returncode == 0:
                logger.info(f"Docker image built successfully: {image_tag}")
                return True
            else:
                logger.error(f"Docker build failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error building Docker image: {e}")
            return False
    
    async def _run_command(self, command: List[str]) -> subprocess.CompletedProcess:
        """非同期コマンド実行"""
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(self.base_dir)
        )
        
        stdout, stderr = await process.communicate()
        
        return subprocess.CompletedProcess(
            args=command,
            returncode=process.returncode,
            stdout=stdout.decode('utf-8'),
            stderr=stderr.decode('utf-8')
        )

class KubernetesBuilder:
    """Kubernetes デプロイメント支援"""
    
    def __init__(self):
        self.base_dir = Path(settings.base_dir)
        self.k8s_dir = self.base_dir / "k8s"
        self.k8s_dir.mkdir(exist_ok=True)
    
    def generate_kubernetes_manifests(self, config: DeploymentConfiguration) -> Dict[str, str]:
        """Kubernetes マニフェスト生成"""
        
        manifests = {}
        
        # Namespace
        manifests["namespace.yaml"] = self._generate_namespace(config)
        
        # ConfigMap
        manifests["configmap.yaml"] = self._generate_configmap(config)
        
        # Secret
        manifests["secret.yaml"] = self._generate_secret(config)
        
        # Deployment
        manifests["deployment.yaml"] = self._generate_deployment(config)
        
        # Service
        manifests["service.yaml"] = self._generate_service(config)
        
        # Ingress (本番環境のみ)
        if config.environment == DeploymentEnvironment.PRODUCTION:
            manifests["ingress.yaml"] = self._generate_ingress(config)
        
        # HorizontalPodAutoscaler
        manifests["hpa.yaml"] = self._generate_hpa(config)
        
        return manifests
    
    def _generate_namespace(self, config: DeploymentConfiguration) -> str:
        """Namespace YAML生成"""
        return f"""
apiVersion: v1
kind: Namespace
metadata:
  name: m365-tools-{config.environment.value}
  labels:
    app: m365-tools
    environment: {config.environment.value}
"""
    
    def _generate_configmap(self, config: DeploymentConfiguration) -> str:
        """ConfigMap YAML生成"""
        return f"""
apiVersion: v1
kind: ConfigMap
metadata:
  name: m365-tools-config
  namespace: m365-tools-{config.environment.value}
data:
  ENVIRONMENT: "{config.environment.value}"
  PYTHONPATH: "/app/src"
  LOG_LEVEL: "INFO"
"""
    
    def _generate_secret(self, config: DeploymentConfiguration) -> str:
        """Secret YAML生成"""
        import base64
        
        secret_data = {}
        for key, value in config.secrets.items():
            secret_data[key] = base64.b64encode(value.encode()).decode()
        
        secret_items = "\n".join([f"  {k}: {v}" for k, v in secret_data.items()])
        
        return f"""
apiVersion: v1
kind: Secret
metadata:
  name: m365-tools-secrets
  namespace: m365-tools-{config.environment.value}
type: Opaque
data:
{secret_items}
"""
    
    def _generate_deployment(self, config: DeploymentConfiguration) -> str:
        """Deployment YAML生成"""
        
        replicas = config.scaling_config.get("min_instances", 1)
        
        return f"""
apiVersion: apps/v1
kind: Deployment
metadata:
  name: m365-tools
  namespace: m365-tools-{config.environment.value}
  labels:
    app: m365-tools
    environment: {config.environment.value}
spec:
  replicas: {replicas}
  selector:
    matchLabels:
      app: m365-tools
  template:
    metadata:
      labels:
        app: m365-tools
        environment: {config.environment.value}
    spec:
      containers:
      - name: m365-tools
        image: m365-tools:{config.environment.value}
        ports:
        - containerPort: 8000
          name: http
        envFrom:
        - configMapRef:
            name: m365-tools-config
        - secretRef:
            name: m365-tools-secrets
        livenessProbe:
          httpGet:
            path: /api/health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        volumeMounts:
        - name: logs
          mountPath: /app/Logs
        - name: reports
          mountPath: /app/Reports
      volumes:
      - name: logs
        emptyDir: {{}}
      - name: reports
        emptyDir: {{}}
"""
    
    def _generate_service(self, config: DeploymentConfiguration) -> str:
        """Service YAML生成"""
        return f"""
apiVersion: v1
kind: Service
metadata:
  name: m365-tools-service
  namespace: m365-tools-{config.environment.value}
  labels:
    app: m365-tools
spec:
  selector:
    app: m365-tools
  ports:
  - port: 80
    targetPort: 8000
    protocol: TCP
    name: http
  type: ClusterIP
"""
    
    def _generate_ingress(self, config: DeploymentConfiguration) -> str:
        """Ingress YAML生成"""
        return f"""
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: m365-tools-ingress
  namespace: m365-tools-{config.environment.value}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - m365-tools.{config.environment.value}.example.com
    secretName: m365-tools-tls
  rules:
  - host: m365-tools.{config.environment.value}.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: m365-tools-service
            port:
              number: 80
"""
    
    def _generate_hpa(self, config: DeploymentConfiguration) -> str:
        """HorizontalPodAutoscaler YAML生成"""
        
        min_replicas = config.scaling_config.get("min_instances", 1)
        max_replicas = config.scaling_config.get("max_instances", 5)
        
        return f"""
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: m365-tools-hpa
  namespace: m365-tools-{config.environment.value}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: m365-tools
  minReplicas: {min_replicas}
  maxReplicas: {max_replicas}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
"""
    
    def save_manifests(self, manifests: Dict[str, str], environment: DeploymentEnvironment):
        """マニフェストファイル保存"""
        env_dir = self.k8s_dir / environment.value
        env_dir.mkdir(exist_ok=True)
        
        for filename, content in manifests.items():
            file_path = env_dir / filename
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content.strip())
        
        logger.info(f"Kubernetes manifests saved to {env_dir}")

class MonitoringIntegration:
    """監視システム統合"""
    
    def __init__(self):
        self.monitoring_configs = {
            "prometheus": self._generate_prometheus_config,
            "grafana": self._generate_grafana_config,
            "alertmanager": self._generate_alertmanager_config
        }
    
    def _generate_prometheus_config(self) -> Dict[str, Any]:
        """Prometheus設定生成"""
        return {
            "global": {
                "scrape_interval": "15s",
                "evaluation_interval": "15s"
            },
            "scrape_configs": [
                {
                    "job_name": "m365-tools",
                    "static_configs": [
                        {"targets": ["localhost:8000"]}
                    ],
                    "metrics_path": "/api/metrics",
                    "scrape_interval": "10s"
                }
            ],
            "rule_files": [
                "m365_tools_rules.yml"
            ],
            "alerting": {
                "alertmanagers": [
                    {
                        "static_configs": [
                            {"targets": ["alertmanager:9093"]}
                        ]
                    }
                ]
            }
        }
    
    def _generate_grafana_config(self) -> Dict[str, Any]:
        """Grafana設定生成"""
        return {
            "apiVersion": 1,
            "datasources": [
                {
                    "name": "Prometheus",
                    "type": "prometheus",
                    "url": "http://prometheus:9090",
                    "access": "proxy",
                    "isDefault": True
                }
            ]
        }
    
    def _generate_alertmanager_config(self) -> Dict[str, Any]:
        """Alertmanager設定生成"""
        return {
            "global": {
                "smtp_smarthost": "localhost:587",
                "smtp_from": "alerts@example.com"
            },
            "route": {
                "group_by": ["alertname"],
                "group_wait": "10s",
                "group_interval": "10s",
                "repeat_interval": "1h",
                "receiver": "web.hook"
            },
            "receivers": [
                {
                    "name": "web.hook",
                    "email_configs": [
                        {
                            "to": "admin@example.com",
                            "subject": "M365 Tools Alert"
                        }
                    ]
                }
            ]
        }

# メインCI/CD支援クラス

class CICDSupportManager:
    """CI/CD統合支援マネージャー"""
    
    def __init__(self):
        self.environment_manager = EnvironmentManager()
        self.docker_builder = DockerBuilder()
        self.k8s_builder = KubernetesBuilder()
        self.monitoring = MonitoringIntegration()
    
    async def setup_development_environment(self) -> Dict[str, Any]:
        """開発環境セットアップ"""
        try:
            config = BuildConfiguration(
                environment=DeploymentEnvironment.DEVELOPMENT,
                build_type=BuildType.DOCKER
            )
            
            # 環境ファイル生成
            env_file_path = Path(settings.base_dir) / ".env.development"
            self.environment_manager.generate_environment_file(
                DeploymentEnvironment.DEVELOPMENT,
                env_file_path
            )
            
            # Docker Compose生成
            deploy_config = DeploymentConfiguration(
                environment=DeploymentEnvironment.DEVELOPMENT,
                target_platform="docker"
            )
            
            compose_content = self.docker_builder.generate_docker_compose(deploy_config)
            compose_path = Path(settings.base_dir) / "docker-compose.development.yml"
            
            with open(compose_path, 'w', encoding='utf-8') as f:
                f.write(compose_content)
            
            return {
                "status": "success",
                "env_file": str(env_file_path),
                "compose_file": str(compose_path),
                "message": "Development environment setup completed"
            }
            
        except Exception as e:
            logger.error(f"Failed to setup development environment: {e}")
            return {"status": "error", "message": str(e)}
    
    async def prepare_production_deployment(self, target_platform: str = "kubernetes") -> Dict[str, Any]:
        """本番デプロイメント準備"""
        try:
            results = {}
            
            # 本番環境設定
            deploy_config = DeploymentConfiguration(
                environment=DeploymentEnvironment.PRODUCTION,
                target_platform=target_platform,
                environment_variables={
                    "WORKERS": "4",
                    "LOG_LEVEL": "INFO",
                    "METRICS_ENABLED": "true"
                },
                scaling_config={
                    "min_instances": 2,
                    "max_instances": 10
                }
            )
            
            if target_platform == "kubernetes":
                # Kubernetes マニフェスト生成
                manifests = self.k8s_builder.generate_kubernetes_manifests(deploy_config)
                self.k8s_builder.save_manifests(manifests, DeploymentEnvironment.PRODUCTION)
                results["kubernetes_manifests"] = list(manifests.keys())
            
            elif target_platform == "docker":
                # Docker Compose生成
                compose_content = self.docker_builder.generate_docker_compose(deploy_config)
                compose_path = Path(settings.base_dir) / "docker-compose.production.yml"
                
                with open(compose_path, 'w', encoding='utf-8') as f:
                    f.write(compose_content)
                
                results["docker_compose"] = str(compose_path)
            
            # 監視設定生成
            monitoring_configs = {}
            for service, generator in self.monitoring.monitoring_configs.items():
                monitoring_configs[service] = generator()
            
            results["monitoring_configs"] = monitoring_configs
            results["status"] = "success"
            results["message"] = f"Production deployment prepared for {target_platform}"
            
            return results
            
        except Exception as e:
            logger.error(f"Failed to prepare production deployment: {e}")
            return {"status": "error", "message": str(e)}
    
    def get_cicd_guidance_for_dev3(self) -> Dict[str, Any]:
        """dev3向けCI/CDガイダンス"""
        return {
            "build_process": {
                "description": "Pythonアプリケーションビルドプロセス",
                "steps": [
                    "1. 依存関係インストール: pip install -r requirements.txt",
                    "2. 型チェック: mypy src/",
                    "3. リンター実行: black src/ && isort src/",
                    "4. テスト実行: pytest src/tests/",
                    "5. セキュリティスキャン: bandit -r src/",
                    "6. Dockerイメージビルド"
                ]
            },
            "deployment_options": {
                "docker": {
                    "description": "Docker コンテナデプロイメント",
                    "files_generated": ["Dockerfile", "docker-compose.yml"],
                    "commands": ["docker build", "docker-compose up"]
                },
                "kubernetes": {
                    "description": "Kubernetes クラスターデプロイメント", 
                    "files_generated": ["deployment.yaml", "service.yaml", "ingress.yaml"],
                    "commands": ["kubectl apply -f k8s/"]
                }
            },
            "environment_management": {
                "description": "環境変数・設定管理",
                "configuration_files": [
                    "appsettings.json (ベース設定)",
                    "appsettings.{environment}.json (環境別設定)",
                    ".env.{environment} (環境変数ファイル)"
                ],
                "environment_override": "M365TOOLS_* 環境変数でオーバーライド可能"
            },
            "monitoring_integration": {
                "description": "監視システム統合",
                "services": ["Prometheus", "Grafana", "Alertmanager"],
                "metrics_endpoint": "/api/metrics",
                "health_endpoint": "/api/health"
            },
            "github_actions_template": self._generate_github_actions_template()
        }
    
    def _generate_github_actions_template(self) -> str:
        """GitHub Actions テンプレート生成"""
        return """
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.9, 3.11]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v3
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install -r requirements-dev.txt
    
    - name: Run type checking
      run: mypy src/
    
    - name: Run linting
      run: |
        black --check src/
        isort --check-only src/
    
    - name: Run security scan
      run: bandit -r src/
    
    - name: Run tests
      run: |
        pytest src/tests/ --cov=src --cov-report=xml
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: |
          ghcr.io/${{ github.repository }}:latest
          ghcr.io/${{ github.repository }}:${{ github.sha }}

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: staging
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to staging
      run: |
        # Kubernetes deployment commands
        kubectl apply -f k8s/staging/
"""

# グローバルインスタンス
cicd_support_manager = CICDSupportManager()

# dev3向けヘルパー関数
async def setup_dev_environment():
    """開発環境セットアップ (dev3向け)"""
    return await cicd_support_manager.setup_development_environment()

async def prepare_production_deployment(platform: str = "kubernetes"):
    """本番デプロイメント準備 (dev3向け)"""
    return await cicd_support_manager.prepare_production_deployment(platform)

def get_cicd_guidance():
    """CI/CDガイダンス取得 (dev3向け)"""
    return cicd_support_manager.get_cicd_guidance_for_dev3()

def get_environment_config(environment: str):
    """環境設定取得 (dev3向け)"""
    env = DeploymentEnvironment(environment)
    return cicd_support_manager.environment_manager.load_environment_config(env)