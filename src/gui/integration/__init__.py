"""
Integration package for team collaboration.
Provides interfaces for coordinating Frontend, Backend, QA, DevOps, Database, and UI/UX integrations.
"""

from .integration_interface import (
    IntegrationInterface,
    FrontendIntegrationInterface,
    IntegrationTask,
    IntegrationResult,
    IntegrationStatus,
    ComponentType
)
from .backend_integration import (
    BackendIntegrationInterface,
    BackendService,
    BackendRequest,
    BackendResponse
)
from .qa_integration import (
    QAIntegrationInterface,
    TestType,
    TestSeverity,
    TestCase,
    TestSuite,
    TestReport
)
from .system_integration import (
    SystemIntegrationManager,
    IntegrationPhase,
    IntegrationPriority,
    IntegrationPlan,
    SystemMetrics
)

__all__ = [
    # Base interfaces
    "IntegrationInterface",
    "FrontendIntegrationInterface",
    "IntegrationTask",
    "IntegrationResult",
    "IntegrationStatus",
    "ComponentType",
    
    # Backend integration
    "BackendIntegrationInterface",
    "BackendService",
    "BackendRequest",
    "BackendResponse",
    
    # QA integration
    "QAIntegrationInterface",
    "TestType",
    "TestSeverity",
    "TestCase",
    "TestSuite",
    "TestReport",
    
    # System integration
    "SystemIntegrationManager",
    "IntegrationPhase",
    "IntegrationPriority",
    "IntegrationPlan",
    "SystemMetrics"
]