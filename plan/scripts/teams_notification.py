#!/usr/bin/env python3
"""
Teams + メール通知システム
Microsoft365ツール開発進捗・エラー通知
"""

import json
import os
import smtplib
import requests
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Dict, List, Optional
import logging

class TeamsNotificationSystem:
    def __init__(self, config_file: str = "Config/appsettings.json"):
        self.config_file = config_file
        self.config = self.load_config()
        self.setup_logging()
        
    def setup_logging(self):
        """ログ設定"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
    def load_config(self) -> Dict:
        """設定ファイル読み込み"""
        if os.path.exists(self.config_file):
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}
        
    def send_teams_message(self, title: str, message: str, urgency: str = "normal") -> bool:
        """Teams通知送信"""
        try:
            # Teams Webhook URL (appsettings.jsonから取得)
            webhook_url = self.config.get("Notifications", {}).get("TeamsWebhookUrl", "")
            
            if not webhook_url:
                self.logger.warning("⚠️ Teams Webhook URL未設定")
                return False
                
            # Teams用メッセージフォーマット
            teams_card = {
                "@type": "MessageCard",
                "@context": "http://schema.org/extensions",
                "themeColor": self.get_theme_color(urgency),
                "summary": title,
                "sections": [{
                    "activityTitle": f"🚀 Microsoft365ツール開発",
                    "activitySubtitle": f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
                    "activityImage": "https://raw.githubusercontent.com/microsoft/vscode-icons/main/icons/file_type_powershell.svg",
                    "facts": [
                        {"name": "プロジェクト", "value": "Microsoft365管理ツール"},
                        {"name": "緊急度", "value": urgency.upper()},
                        {"name": "タイムスタンプ", "value": datetime.now().isoformat()}
                    ],
                    "markdown": True,
                    "text": message
                }],
                "potentialAction": [{
                    "@type": "OpenUri",
                    "name": "GitHub Repository",
                    "targets": [{
                        "os": "default",
                        "uri": "https://github.com/your-org/MicrosoftProductManagementTools"
                    }]
                }]
            }
            
            # Teams送信
            response = requests.post(
                webhook_url,
                json=teams_card,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            
            if response.status_code == 200:
                self.logger.info(f"✅ Teams通知送信成功: {title}")
                return True
            else:
                self.logger.error(f"❌ Teams通知送信失敗: {response.status_code}")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ Teams通知エラー: {str(e)}")
            return False
            
    def send_email_notification(self, to_email: str, subject: str, message: str, urgency: str = "normal") -> bool:
        """メール通知送信"""
        try:
            email_config = self.config.get("Notifications", {}).get("Email", {})
            
            smtp_server = email_config.get("SmtpServer", "smtp.gmail.com")
            smtp_port = email_config.get("SmtpPort", 587)
            from_email = email_config.get("FromEmail", "")
            password = email_config.get("Password", "")
            
            if not from_email or not password:
                self.logger.warning("⚠️ メール設定未完了")
                return False
                
            # HTMLメール作成
            html_message = self.create_html_email(subject, message, urgency)
            
            # MIMEメッセージ作成
            msg = MIMEMultipart('alternative')
            msg['Subject'] = f"🚀 {subject}"
            msg['From'] = from_email
            msg['To'] = to_email
            
            # HTMLパート追加
            html_part = MIMEText(html_message, 'html', 'utf-8')
            msg.attach(html_part)
            
            # SMTP送信
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(from_email, password)
                server.sendmail(from_email, to_email, msg.as_string())
                
            self.logger.info(f"✅ メール送信成功: {to_email}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ メール送信エラー: {str(e)}")
            return False
            
    def get_theme_color(self, urgency: str) -> str:
        """緊急度別テーマカラー"""
        colors = {
            "low": "36a64f",      # 緑
            "normal": "0078d4",   # 青
            "high": "ff8c00",     # オレンジ
            "critical": "ff4444"  # 赤
        }
        return colors.get(urgency, "0078d4")
        
    def create_html_email(self, subject: str, message: str, urgency: str) -> str:
        """HTMLメール本文作成"""
        urgency_emoji = {
            "low": "✅",
            "normal": "📋", 
            "high": "⚠️",
            "critical": "🚨"
        }
        
        html_template = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; }}
                .container {{ max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                .header {{ background: #{self.get_theme_color(urgency)}; color: white; padding: 20px; border-radius: 8px 8px 0 0; }}
                .content {{ padding: 20px; }}
                .footer {{ background: #f5f5f5; padding: 15px; border-radius: 0 0 8px 8px; text-align: center; font-size: 12px; color: #666; }}
                .urgency {{ display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }}
                .urgency.{urgency} {{ background: #{self.get_theme_color(urgency)}20; color: #{self.get_theme_color(urgency)}; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚀 Microsoft365ツール開発</h1>
                    <p>📅 {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}</p>
                </div>
                <div class="content">
                    <h2>{urgency_emoji.get(urgency, "📋")} {subject}</h2>
                    <span class="urgency {urgency}">緊急度: {urgency.upper()}</span>
                    <div style="margin-top: 15px; line-height: 1.6;">
                        {message.replace(chr(10), '<br>')}
                    </div>
                </div>
                <div class="footer">
                    <p>Microsoft365管理ツール 自動通知システム</p>
                    <p>© 2025 Enterprise Tools Project</p>
                </div>
            </div>
        </body>
        </html>
        """
        return html_template
        
    def send_development_update(self, phase: str, completed_tasks: List[str], issues: List[str] = None, next_tasks: List[str] = None) -> bool:
        """開発進捗更新通知"""
        
        # メッセージ作成
        message_parts = [
            f"**フェーズ**: {phase}",
            "",
            "**✅ 完了タスク**:"
        ]
        
        for task in completed_tasks:
            message_parts.append(f"- {task}")
            
        if issues:
            message_parts.extend(["", "**⚠️ 発見された問題**:"])
            for issue in issues:
                message_parts.append(f"- {issue}")
                
        if next_tasks:
            message_parts.extend(["", "**📋 次回タスク**:"])
            for task in next_tasks:
                message_parts.append(f"- {task}")
                
        message = "\n".join(message_parts)
        
        # 緊急度判定
        urgency = "high" if issues else "normal"
        
        # Teams・メール送信
        teams_sent = self.send_teams_message("開発進捗更新", message, urgency)
        
        email_recipients = self.config.get("Notifications", {}).get("EmailRecipients", [])
        email_sent = True
        
        for email in email_recipients:
            if not self.send_email_notification(email, f"開発進捗更新 - {phase}", message, urgency):
                email_sent = False
                
        return teams_sent and email_sent
        
    def send_error_alert(self, error_type: str, error_message: str, stack_trace: str = "", severity: str = "high") -> bool:
        """エラーアラート送信"""
        
        message = f"""
**エラータイプ**: {error_type}

**エラーメッセージ**:
{error_message}

**発生時刻**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
        """
        
        if stack_trace:
            message += f"\n\n**スタックトレース**:\n```\n{stack_trace}\n```"
            
        # Teams・メール送信
        teams_sent = self.send_teams_message(f"🚨 エラーアラート: {error_type}", message, severity)
        
        email_recipients = self.config.get("Notifications", {}).get("EmailRecipients", [])
        email_sent = True
        
        for email in email_recipients:
            if not self.send_email_notification(email, f"エラーアラート - {error_type}", message, severity):
                email_sent = False
                
        return teams_sent and email_sent
        
    def send_milestone_notification(self, milestone_name: str, phase: str, deliverables: List[str]) -> bool:
        """マイルストーン達成通知"""
        
        message = f"""
**🎯 マイルストーン達成**: {milestone_name}

**フェーズ**: {phase}

**📦 成果物**:
        """
        
        for deliverable in deliverables:
            message += f"\n- ✅ {deliverable}"
            
        message += f"\n\n**達成日時**: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}"
        
        # Teams・メール送信
        teams_sent = self.send_teams_message(f"🎯 マイルストーン達成: {milestone_name}", message, "normal")
        
        email_recipients = self.config.get("Notifications", {}).get("EmailRecipients", [])
        email_sent = True
        
        for email in email_recipients:
            if not self.send_email_notification(email, f"マイルストーン達成 - {milestone_name}", message, "normal"):
                email_sent = False
                
        return teams_sent and email_sent


# 使用例・テスト実行
if __name__ == "__main__":
    notification_system = TeamsNotificationSystem()
    
    # 開発進捗更新テスト
    test_completed = ["conftest.py競合解消", "pytest環境確認"]
    test_issues = ["PyQt6依存関係エラー"]
    test_next = ["CI/CD修復", "GUI基盤構築"]
    
    print("📱 Teams + メール通知システムテスト開始")
    
    # 進捗更新通知
    if notification_system.send_development_update(
        "緊急修復フェーズ", 
        test_completed, 
        test_issues, 
        test_next
    ):
        print("✅ 開発進捗更新通知送信成功")
    else:
        print("❌ 開発進捗更新通知送信失敗")
        
    # エラーアラートテスト
    if notification_system.send_error_alert(
        "ImportError",
        "PyQt6モジュールが見つかりません",
        "Traceback (most recent call last):\n  File test.py line 1\n    import PyQt6\nImportError: No module named 'PyQt6'",
        "high"
    ):
        print("✅ エラーアラート送信成功")
    else:
        print("❌ エラーアラート送信失敗")