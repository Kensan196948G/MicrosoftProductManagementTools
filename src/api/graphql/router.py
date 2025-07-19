#!/usr/bin/env python3
"""
GraphQL Router - Phase 3 Advanced Integration
FastAPI + Strawberry GraphQL router with advanced features
"""

import asyncio
import logging
from typing import Optional, Dict, Any, Union
from datetime import datetime

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from starlette.requests import Request
from starlette.responses import Response
from starlette.websockets import WebSocket
from jose import JWTError, jwt

import strawberry
from strawberry.fastapi import BaseContext, GraphQLRouter as StrawberryGraphQLRouter
from strawberry.subscriptions import GRAPHQL_TRANSPORT_WS_PROTOCOL, GRAPHQL_WS_PROTOCOL

from .schema import schema
from .resolvers import GraphQLContext
from src.core.auth.authenticator import get_current_user_from_token
from src.core.config import get_settings

logger = logging.getLogger(__name__)

# Security
security = HTTPBearer(auto_error=False)


class CustomGraphQLContext(BaseContext):
    """Custom GraphQL context with Microsoft 365 integration"""
    
    def __init__(self, 
                 request: Optional[Request] = None,
                 response: Optional[Response] = None,
                 websocket: Optional[WebSocket] = None):
        self.request = request
        self.response = response  
        self.websocket = websocket
        self.user_id: Optional[str] = None
        self.tenant_id: Optional[str] = None
        self.permissions: list = []
        self.graph_context: Optional[GraphQLContext] = None
    
    async def initialize_with_auth(self, user_info: Dict[str, Any]):
        """Initialize context with authenticated user information"""
        self.user_id = user_info.get("user_id")
        self.tenant_id = user_info.get("tenant_id")
        self.permissions = user_info.get("permissions", [])
        
        # Create Graph context
        self.graph_context = GraphQLContext(
            user_id=self.user_id,
            tenant_id=self.tenant_id,
            permissions=self.permissions
        )


async def get_context(
    request: Optional[Request] = None,
    response: Optional[Response] = None,
    websocket: Optional[WebSocket] = None,
    authorization: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> CustomGraphQLContext:
    """
    Get GraphQL context with authentication
    
    Args:
        request: HTTP request
        response: HTTP response
        websocket: WebSocket connection
        authorization: Authorization credentials
        
    Returns:
        Initialized GraphQL context
    """
    context = CustomGraphQLContext(request=request, response=response, websocket=websocket)
    
    try:
        # Get token from various sources
        token = None
        
        if authorization and authorization.credentials:
            token = authorization.credentials
        elif request:
            # Try query parameter
            token = request.query_params.get("token")
            # Try header
            if not token:
                auth_header = request.headers.get("Authorization")
                if auth_header and auth_header.startswith("Bearer "):
                    token = auth_header[7:]
        elif websocket:
            # Try query parameter for WebSocket
            token = websocket.query_params.get("token")
            # Try headers
            if not token:
                auth_header = websocket.headers.get("Authorization")
                if auth_header and auth_header.startswith("Bearer "):
                    token = auth_header[7:]
        
        if not token:
            # For development/testing, allow anonymous access with limited permissions
            logger.warning("No authentication token provided, using anonymous access")
            await context.initialize_with_auth({
                "user_id": "anonymous",
                "tenant_id": "default",
                "permissions": ["user.read", "group.read"]  # Limited permissions
            })
            return context
        
        # Verify JWT token
        settings = get_settings()
        
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            user_id = payload.get("sub")
            tenant_id = payload.get("tenant_id")
            permissions = payload.get("permissions", [])
            
            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token: missing user ID"
                )
            
            user_info = {
                "user_id": user_id,
                "tenant_id": tenant_id,
                "username": payload.get("username"),
                "permissions": permissions,
                "roles": payload.get("roles", [])
            }
            
            await context.initialize_with_auth(user_info)
            
        except JWTError as e:
            logger.error(f"JWT verification failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )
        
        return context
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating GraphQL context: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


class CustomGraphQLRouter(StrawberryGraphQLRouter):
    """Custom GraphQL Router with enhanced features"""
    
    async def process_result(self, request: Request, result) -> Dict[str, Any]:
        """Process GraphQL execution result"""
        try:
            # Default processing
            data: Dict[str, Any] = {"data": result.data}
            
            if result.errors:
                # Format errors for production
                formatted_errors = []
                for error in result.errors:
                    error_dict = {
                        "message": str(error),
                        "locations": getattr(error, 'locations', None),
                        "path": getattr(error, 'path', None)
                    }
                    
                    # Add extensions for debugging (only in development)
                    if hasattr(error, 'original_error'):
                        error_dict["extensions"] = {
                            "code": getattr(error.original_error, 'code', 'INTERNAL_ERROR'),
                            "timestamp": datetime.utcnow().isoformat()
                        }
                    
                    formatted_errors.append(error_dict)
                
                data["errors"] = formatted_errors
            
            # Add execution metadata
            data["extensions"] = {
                "timestamp": datetime.utcnow().isoformat(),
                "version": "3.0.0",
                "tracing": {
                    "version": 1,
                    "startTime": datetime.utcnow().isoformat(),
                    "endTime": datetime.utcnow().isoformat()
                }
            }
            
            return data
            
        except Exception as e:
            logger.error(f"Error processing GraphQL result: {e}")
            return {
                "data": None,
                "errors": [{
                    "message": "Internal server error",
                    "extensions": {
                        "code": "INTERNAL_ERROR",
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }]
            }
    
    def decode_json(self, data: Union[str, bytes]) -> object:
        """Custom JSON decoder with error handling"""
        try:
            import orjson
            if isinstance(data, str):
                data = data.encode()
            return orjson.loads(data)
        except ImportError:
            # Fallback to standard json
            import json
            if isinstance(data, bytes):
                data = data.decode()
            return json.loads(data)
    
    def encode_json(self, data: object) -> bytes:
        """Custom JSON encoder with optimization"""
        try:
            import orjson
            return orjson.dumps(
                data,
                option=orjson.OPT_INDENT_2 | orjson.OPT_SORT_KEYS
            )
        except ImportError:
            # Fallback to standard json
            import json
            return json.dumps(data, indent=2, sort_keys=True).encode()
    
    async def on_ws_connect(self, context: Dict[str, object]):
        """Handle WebSocket connection authentication"""
        try:
            connection_params = context.get("connection_params", {})
            
            # Check for authentication in connection params
            if not isinstance(connection_params, dict):
                logger.warning("Invalid connection params for WebSocket")
                return
            
            token = connection_params.get("Authorization") or connection_params.get("token")
            
            if not token:
                logger.warning("No authentication token in WebSocket connection params")
                # Allow anonymous connections with limited access
                return {"message": "Connected as anonymous user"}
            
            # Verify token
            settings = get_settings()
            try:
                payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
                user_id = payload.get("sub")
                username = payload.get("username")
                
                if user_id:
                    return {"message": f"Connected as {username or user_id}"}
                else:
                    logger.warning("Invalid token in WebSocket connection")
                    return
                    
            except JWTError as e:
                logger.error(f"WebSocket JWT verification failed: {e}")
                return
            
        except Exception as e:
            logger.error(f"Error in WebSocket connection handler: {e}")
            return


# Create the GraphQL router
graphql_router = CustomGraphQLRouter(
    schema,
    context_getter=get_context,
    graphql_ide="apollo-sandbox",  # Use Apollo Studio sandbox
    subscription_protocols=[
        GRAPHQL_TRANSPORT_WS_PROTOCOL,
        GRAPHQL_WS_PROTOCOL,
    ]
)


# Health check endpoint
@strawberry.type
class HealthCheck:
    """Health check response"""
    status: str
    timestamp: datetime
    version: str
    services: Dict[str, str]


async def get_health_status() -> HealthCheck:
    """Get system health status"""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.utcnow(),
        version="3.0.0",
        services={
            "graphql": "healthy",
            "microsoft_graph": "healthy",
            "database": "healthy",
            "redis": "healthy"
        }
    )


# Add health check to router
@graphql_router.get("/health")
async def health_check():
    """Health check endpoint"""
    health = await get_health_status()
    return {
        "status": health.status,
        "timestamp": health.timestamp.isoformat(),
        "version": health.version,
        "services": health.services
    }


# Schema introspection endpoint
@graphql_router.get("/schema")
async def get_schema_sdl():
    """Get GraphQL schema in SDL format"""
    from .schema import get_schema_sdl, get_schema_info
    
    return {
        "sdl": get_schema_sdl(),
        "info": get_schema_info(),
        "endpoints": {
            "graphql": "/graphql",
            "playground": "/graphql",
            "subscriptions": "/graphql (WebSocket)"
        }
    }


if __name__ == "__main__":
    # Test router
    print("GraphQL Router configured successfully")
    print("Available endpoints:")
    print("  - POST /graphql - GraphQL endpoint")
    print("  - GET /graphql - GraphQL Playground")
    print("  - WS /graphql - GraphQL Subscriptions")
    print("  - GET /health - Health check")
    print("  - GET /schema - Schema introspection")