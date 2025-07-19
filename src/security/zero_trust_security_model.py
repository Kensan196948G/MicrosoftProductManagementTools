#!/usr/bin/env python3
"""
Zero-Trust Security Model - CTO継続技術監督Critical実装
Microsoft 365 Management Tools - Zero-Trust Architecture

Features:
- Zero Trust Security Architecture
- Continuous Verification
- Least Privilege Access Control
- Behavioral Analytics
- Risk-Based Authentication
- Micro-Segmentation

Author: Operations Manager - CTO継続技術監督対応
Version: 2.0.0 CTO-SUPERVISED-CRITICAL
Date: 2025-07-19
"""

import asyncio
import logging
import json
import time
import hashlib
import secrets
from typing import Dict, List, Optional, Any, Union, Set, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from enum import Enum
import sqlite3
from pathlib import Path
import ipaddress
import uuid

try:
    import jwt
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa, padding
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    import geoip2.database
    import requests
    from sklearn.ensemble import IsolationForest
    import numpy as np
except ImportError as e:
    print(f"⚠️ Zero-Trust dependencies not available: {e}")
    print("Install with: pip install pyjwt cryptography geoip2 scikit-learn numpy requests")

# Configure logging for zero-trust security
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/microsoft365-zerotrust.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class TrustLevel(Enum):
    """Trust Level Classifications"""
    UNKNOWN = 0
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    VERIFIED = 4


class RiskLevel(Enum):
    """Risk Level Classifications"""
    MINIMAL = "minimal"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class AccessDecision(Enum):
    """Access Control Decisions"""
    ALLOW = "allow"
    DENY = "deny"
    CHALLENGE = "challenge"
    MONITOR = "monitor"
    BLOCK = "block"


@dataclass
class DeviceIdentity:
    """Device Identity and Trust Information"""
    device_id: str
    device_type: str
    os_type: str
    os_version: str
    browser: str
    browser_version: str
    is_managed: bool = False
    is_compliant: bool = False
    trust_level: TrustLevel = TrustLevel.UNKNOWN
    last_seen: datetime = field(default_factory=datetime.utcnow)
    certificates: List[str] = field(default_factory=list)
    security_features: Dict[str, bool] = field(default_factory=dict)
    
    def calculate_device_score(self) -> float:
        """Calculate device trust score (0-100)"""
        score = 0.0
        
        # Base score for known device
        if self.trust_level != TrustLevel.UNKNOWN:
            score += 20.0
        
        # Managed device bonus
        if self.is_managed:
            score += 30.0
        
        # Compliance bonus
        if self.is_compliant:
            score += 25.0
        
        # Security features
        security_bonus = sum(self.security_features.values()) * 5
        score += min(security_bonus, 25.0)
        
        return min(score, 100.0)


@dataclass
class UserBehavior:
    """User Behavioral Analytics Data"""
    user_id: str
    login_patterns: Dict[str, Any] = field(default_factory=dict)
    location_history: List[Dict[str, Any]] = field(default_factory=list)
    access_patterns: Dict[str, Any] = field(default_factory=dict)
    risk_indicators: List[str] = field(default_factory=list)
    baseline_established: bool = False
    last_updated: datetime = field(default_factory=datetime.utcnow)
    
    def calculate_behavior_score(self) -> float:
        """Calculate behavioral trust score (0-100)"""
        if not self.baseline_established:
            return 50.0  # Neutral score for new users
        
        score = 100.0
        
        # Deduct points for risk indicators
        risk_penalty = len(self.risk_indicators) * 10
        score -= min(risk_penalty, 50.0)
        
        # Location consistency check
        if len(self.location_history) > 1:
            recent_locations = self.location_history[-5:]
            unique_countries = set(loc.get('country', 'unknown') for loc in recent_locations)
            if len(unique_countries) > 2:
                score -= 20.0
        
        return max(score, 0.0)


@dataclass
class AccessRequest:
    """Zero-Trust Access Request"""
    request_id: str
    user_id: str
    device_id: str
    resource: str
    action: str
    timestamp: datetime = field(default_factory=datetime.utcnow)
    source_ip: str = ""
    user_agent: str = ""
    location: Dict[str, Any] = field(default_factory=dict)
    context: Dict[str, Any] = field(default_factory=dict)
    
    # Risk assessment results
    user_trust_score: float = 0.0
    device_trust_score: float = 0.0
    location_risk_score: float = 0.0
    behavioral_risk_score: float = 0.0
    overall_risk_level: RiskLevel = RiskLevel.MEDIUM
    access_decision: AccessDecision = AccessDecision.CHALLENGE


@dataclass
class SecurityPolicy:
    """Zero-Trust Security Policy"""
    policy_id: str
    name: str
    description: str
    resource_patterns: List[str]
    conditions: Dict[str, Any]
    actions: Dict[str, Any]
    priority: int = 100
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)


class LocationAnalyzer:
    """Location-based Risk Analysis"""
    
    def __init__(self, geoip_db_path: Optional[str] = None):
        self.geoip_db_path = geoip_db_path
        self.high_risk_countries = {
            'CN', 'RU', 'KP', 'IR'  # Example high-risk country codes
        }
        self.trusted_locations = set()
        
        logger.info("🌍 Location Analyzer initialized")
    
    def analyze_ip_location(self, ip_address: str) -> Dict[str, Any]:
        """Analyze IP address location and risk"""
        try:
            # Validate IP address
            ip_obj = ipaddress.ip_address(ip_address)
            
            location_data = {
                "ip": ip_address,
                "country": "unknown",
                "city": "unknown",
                "is_private": ip_obj.is_private,
                "risk_score": 0.0,
                "risk_factors": []
            }
            
            # Skip analysis for private IPs
            if ip_obj.is_private:
                location_data["risk_score"] = 10.0  # Low risk for internal IPs
                return location_data
            
            # GeoIP lookup (if database available)
            if self.geoip_db_path and Path(self.geoip_db_path).exists():
                try:
                    with geoip2.database.Reader(self.geoip_db_path) as reader:
                        response = reader.city(ip_address)
                        location_data.update({
                            "country": response.country.iso_code,
                            "city": response.city.name,
                            "latitude": float(response.location.latitude or 0),
                            "longitude": float(response.location.longitude or 0)
                        })
                except Exception as e:
                    logger.warning(f"GeoIP lookup failed for {ip_address}: {e}")
            
            # Calculate risk score
            risk_score = self._calculate_location_risk(location_data)
            location_data["risk_score"] = risk_score
            
            return location_data
            
        except Exception as e:
            logger.error(f"Location analysis failed for {ip_address}: {e}")
            return {
                "ip": ip_address,
                "country": "unknown",
                "city": "unknown",
                "is_private": False,
                "risk_score": 50.0,
                "risk_factors": ["analysis_failed"],
                "error": str(e)
            }
    
    def _calculate_location_risk(self, location_data: Dict[str, Any]) -> float:
        """Calculate location-based risk score (0-100)"""
        risk_score = 0.0
        risk_factors = []
        
        country = location_data.get("country", "unknown")
        
        # High-risk country check
        if country in self.high_risk_countries:
            risk_score += 40.0
            risk_factors.append("high_risk_country")
        
        # Unknown location
        if country == "unknown":
            risk_score += 30.0
            risk_factors.append("unknown_location")
        
        # Trusted location check
        location_key = f"{country}:{location_data.get('city', 'unknown')}"
        if location_key not in self.trusted_locations:
            risk_score += 20.0
            risk_factors.append("untrusted_location")
        
        location_data["risk_factors"] = risk_factors
        return min(risk_score, 100.0)
    
    def add_trusted_location(self, country: str, city: str = ""):
        """Add trusted location"""
        location_key = f"{country}:{city}" if city else f"{country}:*"
        self.trusted_locations.add(location_key)
        logger.info(f"🌍 Added trusted location: {location_key}")


class BehavioralAnalyzer:
    """Behavioral Analytics Engine"""
    
    def __init__(self):
        self.user_behaviors: Dict[str, UserBehavior] = {}
        self.anomaly_detector = IsolationForest(
            contamination=0.1,
            random_state=42
        )
        self.is_model_trained = False
        
        logger.info("🧠 Behavioral Analyzer initialized")
    
    def analyze_user_behavior(self, 
                            user_id: str, 
                            access_request: AccessRequest) -> Dict[str, Any]:
        """Analyze user behavioral patterns"""
        try:
            # Get or create user behavior profile
            if user_id not in self.user_behaviors:
                self.user_behaviors[user_id] = UserBehavior(user_id=user_id)
            
            behavior = self.user_behaviors[user_id]
            
            # Update behavioral data
            self._update_login_patterns(behavior, access_request)
            self._update_location_history(behavior, access_request)
            self._update_access_patterns(behavior, access_request)
            
            # Detect anomalies
            anomalies = self._detect_anomalies(behavior, access_request)
            
            # Calculate risk indicators
            risk_indicators = self._calculate_risk_indicators(behavior, access_request)
            behavior.risk_indicators = risk_indicators
            
            # Calculate behavioral score
            behavioral_score = behavior.calculate_behavior_score()
            
            analysis_result = {
                "user_id": user_id,
                "behavioral_score": behavioral_score,
                "anomalies": anomalies,
                "risk_indicators": risk_indicators,
                "baseline_established": behavior.baseline_established,
                "analysis_timestamp": datetime.utcnow().isoformat()
            }
            
            # Update last seen
            behavior.last_updated = datetime.utcnow()
            
            return analysis_result
            
        except Exception as e:
            logger.error(f"Behavioral analysis failed for user {user_id}: {e}")
            return {
                "user_id": user_id,
                "behavioral_score": 50.0,
                "anomalies": [],
                "risk_indicators": ["analysis_failed"],
                "baseline_established": False,
                "error": str(e)
            }
    
    def _update_login_patterns(self, behavior: UserBehavior, request: AccessRequest):
        """Update login time patterns"""
        hour = request.timestamp.hour
        day_of_week = request.timestamp.weekday()
        
        if "hours" not in behavior.login_patterns:
            behavior.login_patterns["hours"] = {}
        if "days" not in behavior.login_patterns:
            behavior.login_patterns["days"] = {}
        
        # Count login hours
        hour_key = str(hour)
        behavior.login_patterns["hours"][hour_key] = behavior.login_patterns["hours"].get(hour_key, 0) + 1
        
        # Count login days
        day_key = str(day_of_week)
        behavior.login_patterns["days"][day_key] = behavior.login_patterns["days"].get(day_key, 0) + 1
        
        # Establish baseline after 50 login events
        total_logins = sum(behavior.login_patterns["hours"].values())
        if total_logins >= 50:
            behavior.baseline_established = True
    
    def _update_location_history(self, behavior: UserBehavior, request: AccessRequest):
        """Update location history"""
        location_entry = {
            "timestamp": request.timestamp.isoformat(),
            "ip": request.source_ip,
            "country": request.location.get("country", "unknown"),
            "city": request.location.get("city", "unknown")
        }
        
        behavior.location_history.append(location_entry)
        
        # Keep only last 100 locations
        if len(behavior.location_history) > 100:
            behavior.location_history = behavior.location_history[-100:]
    
    def _update_access_patterns(self, behavior: UserBehavior, request: AccessRequest):
        """Update resource access patterns"""
        resource = request.resource
        action = request.action
        
        if "resources" not in behavior.access_patterns:
            behavior.access_patterns["resources"] = {}
        if "actions" not in behavior.access_patterns:
            behavior.access_patterns["actions"] = {}
        
        # Count resource access
        behavior.access_patterns["resources"][resource] = behavior.access_patterns["resources"].get(resource, 0) + 1
        
        # Count action types
        behavior.access_patterns["actions"][action] = behavior.access_patterns["actions"].get(action, 0) + 1
    
    def _detect_anomalies(self, behavior: UserBehavior, request: AccessRequest) -> List[str]:
        """Detect behavioral anomalies"""
        anomalies = []
        
        if not behavior.baseline_established:
            return anomalies
        
        # Unusual time access
        hour = request.timestamp.hour
        hour_key = str(hour)
        hour_count = behavior.login_patterns.get("hours", {}).get(hour_key, 0)
        total_logins = sum(behavior.login_patterns.get("hours", {}).values())
        
        if total_logins > 0:
            hour_frequency = hour_count / total_logins
            if hour_frequency < 0.05:  # Less than 5% of usual activity
                anomalies.append("unusual_time_access")
        
        # Unusual location
        current_country = request.location.get("country", "unknown")
        recent_countries = [loc.get("country", "unknown") for loc in behavior.location_history[-10:]]
        if current_country not in recent_countries and current_country != "unknown":
            anomalies.append("unusual_location")
        
        # Unusual resource access
        resource = request.resource
        resource_count = behavior.access_patterns.get("resources", {}).get(resource, 0)
        if resource_count == 0:
            anomalies.append("new_resource_access")
        
        return anomalies
    
    def _calculate_risk_indicators(self, behavior: UserBehavior, request: AccessRequest) -> List[str]:
        """Calculate risk indicators"""
        indicators = []
        
        # Multiple locations in short time
        if len(behavior.location_history) >= 2:
            last_location = behavior.location_history[-1]
            current_time = request.timestamp
            last_time = datetime.fromisoformat(last_location["timestamp"])
            
            if current_time - last_time < timedelta(hours=1):
                last_country = last_location.get("country", "unknown")
                current_country = request.location.get("country", "unknown")
                if last_country != current_country and last_country != "unknown" and current_country != "unknown":
                    indicators.append("impossible_travel")
        
        # High-frequency access
        recent_requests = [loc for loc in behavior.location_history if 
                         datetime.fromisoformat(loc["timestamp"]) > datetime.utcnow() - timedelta(minutes=10)]
        if len(recent_requests) > 20:
            indicators.append("high_frequency_access")
        
        return indicators


class RiskEngine:
    """Zero-Trust Risk Assessment Engine"""
    
    def __init__(self):
        self.location_analyzer = LocationAnalyzer()
        self.behavioral_analyzer = BehavioralAnalyzer()
        self.device_registry: Dict[str, DeviceIdentity] = {}
        
        logger.info("⚖️ Risk Engine initialized")
    
    def assess_access_request(self, access_request: AccessRequest) -> AccessRequest:
        """Perform comprehensive risk assessment"""
        try:
            # Device trust assessment
            device_score = self._assess_device_trust(access_request.device_id, access_request.user_agent)
            access_request.device_trust_score = device_score
            
            # Location risk assessment
            location_analysis = self.location_analyzer.analyze_ip_location(access_request.source_ip)
            access_request.location = location_analysis
            access_request.location_risk_score = location_analysis.get("risk_score", 50.0)
            
            # Behavioral analysis
            behavioral_analysis = self.behavioral_analyzer.analyze_user_behavior(
                access_request.user_id, access_request
            )
            access_request.behavioral_risk_score = 100.0 - behavioral_analysis.get("behavioral_score", 50.0)
            
            # User trust assessment (placeholder - integrate with user profile)
            access_request.user_trust_score = self._assess_user_trust(access_request.user_id)
            
            # Calculate overall risk
            overall_risk = self._calculate_overall_risk(access_request)
            access_request.overall_risk_level = overall_risk
            
            # Make access decision
            access_decision = self._make_access_decision(access_request)
            access_request.access_decision = access_decision
            
            logger.info(f"🔍 Risk assessment completed for user {access_request.user_id}: {overall_risk.value}")
            
            return access_request
            
        except Exception as e:
            logger.error(f"Risk assessment failed: {e}")
            access_request.overall_risk_level = RiskLevel.HIGH
            access_request.access_decision = AccessDecision.DENY
            return access_request
    
    def _assess_device_trust(self, device_id: str, user_agent: str) -> float:
        """Assess device trustworthiness"""
        if device_id in self.device_registry:
            device = self.device_registry[device_id]
            return device.calculate_device_score()
        else:
            # New device - create basic profile
            device = DeviceIdentity(
                device_id=device_id,
                device_type="unknown",
                os_type="unknown",
                os_version="unknown",
                browser="unknown",
                browser_version="unknown"
            )
            
            # Parse user agent for basic info
            if user_agent:
                device = self._parse_user_agent(device, user_agent)
            
            self.device_registry[device_id] = device
            return device.calculate_device_score()
    
    def _parse_user_agent(self, device: DeviceIdentity, user_agent: str) -> DeviceIdentity:
        """Parse user agent for device information"""
        user_agent_lower = user_agent.lower()
        
        # OS detection
        if "windows" in user_agent_lower:
            device.os_type = "Windows"
        elif "macos" in user_agent_lower or "mac os" in user_agent_lower:
            device.os_type = "macOS"
        elif "linux" in user_agent_lower:
            device.os_type = "Linux"
        elif "android" in user_agent_lower:
            device.os_type = "Android"
        elif "ios" in user_agent_lower:
            device.os_type = "iOS"
        
        # Browser detection
        if "chrome" in user_agent_lower:
            device.browser = "Chrome"
        elif "firefox" in user_agent_lower:
            device.browser = "Firefox"
        elif "safari" in user_agent_lower:
            device.browser = "Safari"
        elif "edge" in user_agent_lower:
            device.browser = "Edge"
        
        return device
    
    def _assess_user_trust(self, user_id: str) -> float:
        """Assess user trustworthiness (placeholder)"""
        # This would integrate with user profile, role, privileges, etc.
        # For now, return a baseline score
        return 75.0
    
    def _calculate_overall_risk(self, request: AccessRequest) -> RiskLevel:
        """Calculate overall risk level"""
        # Weighted risk calculation
        device_weight = 0.25
        location_weight = 0.20
        behavioral_weight = 0.35
        user_weight = 0.20
        
        # Convert trust scores to risk scores (inverse)
        device_risk = 100.0 - request.device_trust_score
        user_risk = 100.0 - request.user_trust_score
        
        overall_risk_score = (
            device_risk * device_weight +
            request.location_risk_score * location_weight +
            request.behavioral_risk_score * behavioral_weight +
            user_risk * user_weight
        )
        
        # Map score to risk level
        if overall_risk_score < 20:
            return RiskLevel.MINIMAL
        elif overall_risk_score < 40:
            return RiskLevel.LOW
        elif overall_risk_score < 60:
            return RiskLevel.MEDIUM
        elif overall_risk_score < 80:
            return RiskLevel.HIGH
        else:
            return RiskLevel.CRITICAL
    
    def _make_access_decision(self, request: AccessRequest) -> AccessDecision:
        """Make access control decision based on risk"""
        risk_level = request.overall_risk_level
        
        # Decision matrix based on risk level
        if risk_level == RiskLevel.MINIMAL:
            return AccessDecision.ALLOW
        elif risk_level == RiskLevel.LOW:
            return AccessDecision.ALLOW
        elif risk_level == RiskLevel.MEDIUM:
            return AccessDecision.CHALLENGE
        elif risk_level == RiskLevel.HIGH:
            return AccessDecision.CHALLENGE
        else:  # CRITICAL
            return AccessDecision.DENY
    
    def register_trusted_device(self, device_id: str, device_info: Dict[str, Any]):
        """Register a trusted device"""
        device = DeviceIdentity(
            device_id=device_id,
            device_type=device_info.get("type", "unknown"),
            os_type=device_info.get("os_type", "unknown"),
            os_version=device_info.get("os_version", "unknown"),
            browser=device_info.get("browser", "unknown"),
            browser_version=device_info.get("browser_version", "unknown"),
            is_managed=device_info.get("is_managed", False),
            is_compliant=device_info.get("is_compliant", False),
            trust_level=TrustLevel.HIGH
        )
        
        self.device_registry[device_id] = device
        logger.info(f"📱 Trusted device registered: {device_id}")


class PolicyEngine:
    """Zero-Trust Policy Engine"""
    
    def __init__(self):
        self.policies: List[SecurityPolicy] = []
        self._load_default_policies()
        
        logger.info("📋 Policy Engine initialized")
    
    def _load_default_policies(self):
        """Load default zero-trust policies"""
        default_policies = [
            SecurityPolicy(
                policy_id="admin_high_risk",
                name="Admin Access High Risk Locations",
                description="Deny admin access from high-risk locations",
                resource_patterns=["admin/*", "management/*"],
                conditions={
                    "location_risk_score": {"operator": ">", "value": 60},
                    "user_roles": {"operator": "contains", "value": "admin"}
                },
                actions={"decision": "deny", "reason": "High-risk location for admin access"},
                priority=10
            ),
            SecurityPolicy(
                policy_id="mfa_required_critical",
                name="MFA Required for Critical Resources",
                description="Require MFA for critical resource access",
                resource_patterns=["critical/*", "finance/*", "hr/*"],
                conditions={
                    "overall_risk_level": {"operator": ">=", "value": "medium"}
                },
                actions={"decision": "challenge", "mfa_required": True},
                priority=20
            ),
            SecurityPolicy(
                policy_id="new_device_challenge",
                name="Challenge New Devices",
                description="Challenge access from new or untrusted devices",
                resource_patterns=["*"],
                conditions={
                    "device_trust_score": {"operator": "<", "value": 50}
                },
                actions={"decision": "challenge", "device_verification": True},
                priority=30
            )
        ]
        
        self.policies.extend(default_policies)
        logger.info(f"📋 Loaded {len(default_policies)} default policies")
    
    def evaluate_policies(self, access_request: AccessRequest) -> Dict[str, Any]:
        """Evaluate policies against access request"""
        policy_results = []
        
        for policy in sorted(self.policies, key=lambda p: p.priority):
            if not policy.is_active:
                continue
            
            # Check if resource matches
            if not self._resource_matches(access_request.resource, policy.resource_patterns):
                continue
            
            # Evaluate conditions
            if self._evaluate_conditions(access_request, policy.conditions):
                policy_results.append({
                    "policy_id": policy.policy_id,
                    "name": policy.name,
                    "matched": True,
                    "actions": policy.actions,
                    "priority": policy.priority
                })
                
                # Apply policy actions if it's a blocking decision
                if policy.actions.get("decision") == "deny":
                    return {
                        "decision": AccessDecision.DENY,
                        "reason": policy.actions.get("reason", "Access denied by policy"),
                        "matched_policies": policy_results
                    }
        
        # Determine final decision from matched policies
        if policy_results:
            # Use highest priority (lowest number) policy action
            primary_policy = min(policy_results, key=lambda p: p["priority"])
            decision_str = primary_policy["actions"].get("decision", "allow")
            
            try:
                decision = AccessDecision(decision_str)
            except ValueError:
                decision = AccessDecision.CHALLENGE
            
            return {
                "decision": decision,
                "reason": f"Policy: {primary_policy['name']}",
                "matched_policies": policy_results
            }
        
        # No policies matched - use risk-based decision
        return {
            "decision": access_request.access_decision,
            "reason": "Risk-based decision",
            "matched_policies": []
        }
    
    def _resource_matches(self, resource: str, patterns: List[str]) -> bool:
        """Check if resource matches any pattern"""
        for pattern in patterns:
            if pattern == "*":
                return True
            if pattern.endswith("*"):
                if resource.startswith(pattern[:-1]):
                    return True
            elif resource == pattern:
                return True
        return False
    
    def _evaluate_conditions(self, request: AccessRequest, conditions: Dict[str, Any]) -> bool:
        """Evaluate policy conditions"""
        for condition_key, condition_value in conditions.items():
            if not self._evaluate_single_condition(request, condition_key, condition_value):
                return False
        return True
    
    def _evaluate_single_condition(self, 
                                 request: AccessRequest, 
                                 key: str, 
                                 condition: Dict[str, Any]) -> bool:
        """Evaluate single condition"""
        operator = condition.get("operator", "==")
        expected_value = condition.get("value")
        
        # Get actual value from request
        if key == "location_risk_score":
            actual_value = request.location_risk_score
        elif key == "device_trust_score":
            actual_value = request.device_trust_score
        elif key == "user_trust_score":
            actual_value = request.user_trust_score
        elif key == "behavioral_risk_score":
            actual_value = request.behavioral_risk_score
        elif key == "overall_risk_level":
            actual_value = request.overall_risk_level.value
        else:
            # Check in context
            actual_value = request.context.get(key)
        
        # Evaluate based on operator
        if operator == "==" or operator == "equals":
            return actual_value == expected_value
        elif operator == ">" or operator == "greater_than":
            return actual_value > expected_value
        elif operator == "<" or operator == "less_than":
            return actual_value < expected_value
        elif operator == ">=" or operator == "greater_equal":
            return actual_value >= expected_value
        elif operator == "<=" or operator == "less_equal":
            return actual_value <= expected_value
        elif operator == "contains":
            return expected_value in str(actual_value)
        else:
            return False
    
    def add_policy(self, policy: SecurityPolicy):
        """Add new security policy"""
        self.policies.append(policy)
        logger.info(f"📋 Policy added: {policy.name}")
    
    def remove_policy(self, policy_id: str):
        """Remove security policy"""
        self.policies = [p for p in self.policies if p.policy_id != policy_id]
        logger.info(f"📋 Policy removed: {policy_id}")


class ZeroTrustSecurityManager:
    """
    Zero-Trust Security Manager
    CTO継続技術監督Critical実装
    """
    
    def __init__(self, config_path: str = "config/zerotrust_config.json"):
        self.config = self._load_config(config_path)
        self.risk_engine = RiskEngine()
        self.policy_engine = PolicyEngine()
        
        # Database setup
        self.db_path = self.config.get("database", {}).get("path", "zerotrust_database.db")
        self._init_database()
        
        # Access logs
        self.access_logs: List[AccessRequest] = []
        
        logger.info("🛡️ Zero-Trust Security Manager initialized - CTO Supervised")
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load zero-trust configuration"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Zero-trust config file not found: {config_path}, using defaults")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Default zero-trust configuration"""
        return {
            "risk_thresholds": {
                "device_trust_minimum": 30.0,
                "location_risk_maximum": 70.0,
                "behavioral_risk_maximum": 60.0
            },
            "challenge_requirements": {
                "mfa_enabled": True,
                "device_verification": True,
                "session_timeout": 3600  # 1 hour
            },
            "monitoring": {
                "log_all_requests": True,
                "alert_on_high_risk": True,
                "continuous_evaluation": True
            },
            "database": {
                "path": "zerotrust_database.db"
            }
        }
    
    def _init_database(self):
        """Initialize zero-trust database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Access requests table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS access_requests (
                    request_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    device_id TEXT NOT NULL,
                    resource TEXT NOT NULL,
                    action TEXT NOT NULL,
                    source_ip TEXT,
                    user_agent TEXT,
                    location_data TEXT,
                    user_trust_score REAL,
                    device_trust_score REAL,
                    location_risk_score REAL,
                    behavioral_risk_score REAL,
                    overall_risk_level TEXT,
                    access_decision TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Security events table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS security_events (
                    event_id TEXT PRIMARY KEY,
                    event_type TEXT NOT NULL,
                    user_id TEXT,
                    device_id TEXT,
                    description TEXT,
                    severity TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    resolved BOOLEAN DEFAULT FALSE
                )
            ''')
            
            # Trusted devices table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS trusted_devices (
                    device_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    device_type TEXT,
                    os_type TEXT,
                    trust_level TEXT,
                    is_managed BOOLEAN DEFAULT FALSE,
                    is_compliant BOOLEAN DEFAULT FALSE,
                    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    last_seen DATETIME
                )
            ''')
            
            conn.commit()
            conn.close()
            
            logger.info("🗄️ Zero-trust database initialized")
            
        except Exception as e:
            logger.error(f"Zero-trust database initialization failed: {e}")
    
    async def evaluate_access_request(self, 
                                    user_id: str,
                                    device_id: str,
                                    resource: str,
                                    action: str,
                                    source_ip: str = "",
                                    user_agent: str = "",
                                    context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Evaluate zero-trust access request"""
        try:
            # Create access request
            access_request = AccessRequest(
                request_id=str(uuid.uuid4()),
                user_id=user_id,
                device_id=device_id,
                resource=resource,
                action=action,
                source_ip=source_ip,
                user_agent=user_agent,
                context=context or {}
            )
            
            # Risk assessment
            assessed_request = self.risk_engine.assess_access_request(access_request)
            
            # Policy evaluation
            policy_result = self.policy_engine.evaluate_policies(assessed_request)
            
            # Final decision
            final_decision = policy_result["decision"]
            reason = policy_result["reason"]
            
            # Log request
            await self._log_access_request(assessed_request, final_decision, reason)
            
            # Generate security events if needed
            await self._check_security_events(assessed_request)
            
            logger.info(f"🔍 Access evaluation: {user_id} -> {resource} = {final_decision.value}")
            
            return {
                "request_id": assessed_request.request_id,
                "decision": final_decision.value,
                "reason": reason,
                "risk_assessment": {
                    "user_trust_score": assessed_request.user_trust_score,
                    "device_trust_score": assessed_request.device_trust_score,
                    "location_risk_score": assessed_request.location_risk_score,
                    "behavioral_risk_score": assessed_request.behavioral_risk_score,
                    "overall_risk_level": assessed_request.overall_risk_level.value
                },
                "policy_results": policy_result.get("matched_policies", []),
                "timestamp": assessed_request.timestamp.isoformat()
            }
            
        except Exception as e:
            logger.error(f"Access evaluation failed: {e}")
            return {
                "request_id": str(uuid.uuid4()),
                "decision": AccessDecision.DENY.value,
                "reason": f"Evaluation error: {str(e)}",
                "error": True
            }
    
    async def _log_access_request(self, 
                                request: AccessRequest, 
                                decision: AccessDecision, 
                                reason: str):
        """Log access request to database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO access_requests 
                (request_id, user_id, device_id, resource, action, source_ip, user_agent,
                 location_data, user_trust_score, device_trust_score, location_risk_score,
                 behavioral_risk_score, overall_risk_level, access_decision, timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                request.request_id, request.user_id, request.device_id, request.resource,
                request.action, request.source_ip, request.user_agent,
                json.dumps(request.location), request.user_trust_score,
                request.device_trust_score, request.location_risk_score,
                request.behavioral_risk_score, request.overall_risk_level.value,
                decision.value, request.timestamp.isoformat()
            ))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to log access request: {e}")
    
    async def _check_security_events(self, request: AccessRequest):
        """Check for security events"""
        events = []
        
        # High-risk access attempt
        if request.overall_risk_level in [RiskLevel.HIGH, RiskLevel.CRITICAL]:
            events.append({
                "event_type": "high_risk_access",
                "description": f"High-risk access attempt from {request.source_ip}",
                "severity": "high"
            })
        
        # Multiple failed attempts (would need session tracking)
        # Impossible travel (handled in behavioral analyzer)
        
        # Log security events
        for event in events:
            await self._log_security_event(
                event["event_type"],
                request.user_id,
                request.device_id,
                event["description"],
                event["severity"]
            )
    
    async def _log_security_event(self, 
                                event_type: str,
                                user_id: str,
                                device_id: str,
                                description: str,
                                severity: str):
        """Log security event"""
        try:
            event_id = str(uuid.uuid4())
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO security_events 
                (event_id, event_type, user_id, device_id, description, severity)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (event_id, event_type, user_id, device_id, description, severity))
            
            conn.commit()
            conn.close()
            
            logger.warning(f"🚨 Security event: {event_type} - {description}")
            
        except Exception as e:
            logger.error(f"Failed to log security event: {e}")
    
    async def register_trusted_device(self, 
                                    user_id: str,
                                    device_id: str,
                                    device_info: Dict[str, Any]) -> Dict[str, Any]:
        """Register trusted device"""
        try:
            # Register with risk engine
            self.risk_engine.register_trusted_device(device_id, device_info)
            
            # Save to database
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT OR REPLACE INTO trusted_devices 
                (device_id, user_id, device_type, os_type, trust_level, 
                 is_managed, is_compliant, last_seen)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                device_id, user_id, device_info.get("type", "unknown"),
                device_info.get("os_type", "unknown"), "high",
                device_info.get("is_managed", False),
                device_info.get("is_compliant", False),
                datetime.utcnow().isoformat()
            ))
            
            conn.commit()
            conn.close()
            
            logger.info(f"📱 Trusted device registered: {device_id} for user {user_id}")
            
            return {"status": "success", "device_id": device_id}
            
        except Exception as e:
            logger.error(f"Failed to register trusted device: {e}")
            return {"status": "error", "error": str(e)}
    
    def get_security_dashboard(self) -> Dict[str, Any]:
        """Get security dashboard data"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Access request statistics
            cursor.execute('''
                SELECT access_decision, COUNT(*) 
                FROM access_requests 
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY access_decision
            ''')
            access_stats = dict(cursor.fetchall())
            
            # Risk level distribution
            cursor.execute('''
                SELECT overall_risk_level, COUNT(*) 
                FROM access_requests 
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY overall_risk_level
            ''')
            risk_stats = dict(cursor.fetchall())
            
            # Top risky users
            cursor.execute('''
                SELECT user_id, AVG(location_risk_score + behavioral_risk_score) as avg_risk
                FROM access_requests 
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY user_id
                ORDER BY avg_risk DESC
                LIMIT 10
            ''')
            risky_users = cursor.fetchall()
            
            # Recent security events
            cursor.execute('''
                SELECT event_type, COUNT(*) 
                FROM security_events 
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY event_type
            ''')
            security_events = dict(cursor.fetchall())
            
            conn.close()
            
            return {
                "access_statistics": access_stats,
                "risk_distribution": risk_stats,
                "risky_users": risky_users,
                "security_events": security_events,
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Failed to get security dashboard: {e}")
            return {"error": str(e)}


# Global zero-trust manager instance
zero_trust_manager = ZeroTrustSecurityManager()


async def setup_zero_trust_security() -> Dict[str, Any]:
    """Setup zero-trust security system"""
    print("🛡️ Microsoft 365 Zero-Trust Security - CTO継続技術監督Critical")
    print("Setting up zero-trust security architecture...")
    
    try:
        # Test access evaluation
        test_result = await zero_trust_manager.evaluate_access_request(
            user_id="test_user_001",
            device_id="test_device_001",
            resource="microsoft365/users",
            action="read",
            source_ip="192.168.1.100",
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0"
        )
        
        print(f"Test Access Evaluation: {test_result['decision']}")
        
        # Register test trusted device
        device_result = await zero_trust_manager.register_trusted_device(
            user_id="test_user_001",
            device_id="trusted_device_001",
            device_info={
                "type": "laptop",
                "os_type": "Windows",
                "is_managed": True,
                "is_compliant": True
            }
        )
        
        print(f"Trusted Device Registration: {device_result['status']}")
        
        # Get security dashboard
        dashboard = zero_trust_manager.get_security_dashboard()
        print(f"Security Dashboard: {len(dashboard)} metrics")
        
        return {
            "status": "success",
            "test_evaluation": test_result,
            "device_registration": device_result,
            "dashboard": dashboard
        }
        
    except Exception as e:
        print(f"❌ Zero-trust setup error: {e}")
        return {"status": "error", "error": str(e)}


if __name__ == "__main__":
    asyncio.run(setup_zero_trust_security())