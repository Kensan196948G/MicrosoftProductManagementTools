#!/usr/bin/env python3
"""
Context7 API制限対処・最適化システム
Microsoft 365 Python移行プロジェクト - API制限緊急対処

🚀 緊急実装: Context7 API制限課題対処
- レート制限回避
- キャッシング戦略
- 非同期処理最適化
- エラーハンドリング強化
"""

import asyncio
import aiohttp
import time
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Union
from pathlib import Path
import hashlib
from dataclasses import dataclass
from contextlib import asynccontextmanager

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class RateLimitInfo:
    """レート制限情報"""
    requests_per_minute: int = 60
    requests_per_hour: int = 1000
    requests_per_day: int = 10000
    current_minute_count: int = 0
    current_hour_count: int = 0
    current_day_count: int = 0
    last_reset_minute: datetime = None
    last_reset_hour: datetime = None
    last_reset_day: datetime = None

class Context7APIOptimizer:
    """
    Context7 API制限対処・最適化システム
    レート制限回避・キャッシング・非同期処理最適化
    """
    
    def __init__(self, cache_dir: str = "cache/context7"):
        """
        初期化
        
        Args:
            cache_dir: キャッシュディレクトリパス
        """
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # レート制限管理
        self.rate_limit = RateLimitInfo()
        
        # キャッシュ設定
        self.cache_ttl_hours = 24  # キャッシュ有効期限（時間）
        self.memory_cache: Dict[str, Any] = {}
        
        # 非同期セッション
        self.session: Optional[aiohttp.ClientSession] = None
        
        # バックオフ設定
        self.base_delay = 1.0  # 基本遅延時間（秒）
        self.max_delay = 60.0  # 最大遅延時間（秒）
        self.backoff_factor = 2.0  # バックオフ倍率
        
        logger.info("✅ Context7 API最適化システム初期化完了")
    
    async def __aenter__(self):
        """非同期コンテキストマネージャー開始"""
        await self.start_session()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """非同期コンテキストマネージャー終了"""
        await self.close_session()
    
    async def start_session(self):
        """HTTPセッション開始"""
        if not self.session:
            timeout = aiohttp.ClientTimeout(total=30, connect=10)
            connector = aiohttp.TCPConnector(
                limit=100,  # 最大同時接続数
                limit_per_host=10,  # ホスト別最大接続数
                ttl_dns_cache=300,  # DNS キャッシュTTL
                use_dns_cache=True
            )
            
            self.session = aiohttp.ClientSession(
                timeout=timeout,
                connector=connector,
                headers={
                    "User-Agent": "Microsoft365Tools-Python/3.0",
                    "Accept": "application/json",
                    "Accept-Encoding": "gzip, deflate"
                }
            )
            logger.info("✅ HTTP セッション開始完了")
    
    async def close_session(self):
        """HTTPセッション終了"""
        if self.session:
            await self.session.close()
            self.session = None
            logger.info("✅ HTTP セッション終了完了")
    
    def _generate_cache_key(self, url: str, params: Dict = None) -> str:
        """キャッシュキー生成"""
        cache_data = {"url": url, "params": params or {}}
        cache_str = json.dumps(cache_data, sort_keys=True)
        return hashlib.md5(cache_str.encode(), usedforsecurity=False).hexdigest()
    
    def _is_cache_valid(self, cache_file: Path) -> bool:
        """キャッシュ有効性確認"""
        if not cache_file.exists():
            return False
        
        # ファイル更新時刻確認
        file_mtime = datetime.fromtimestamp(cache_file.stat().st_mtime)
        expiry_time = file_mtime + timedelta(hours=self.cache_ttl_hours)
        
        return datetime.now() < expiry_time
    
    async def _load_from_cache(self, cache_key: str) -> Optional[Any]:
        """キャッシュから読み込み"""
        try:
            # メモリキャッシュ確認
            if cache_key in self.memory_cache:
                logger.debug(f"📋 メモリキャッシュヒット: {cache_key[:8]}")
                return self.memory_cache[cache_key]
            
            # ファイルキャッシュ確認
            cache_file = self.cache_dir / f"{cache_key}.json"
            if self._is_cache_valid(cache_file):
                with open(cache_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                # メモリキャッシュに保存
                self.memory_cache[cache_key] = data
                logger.debug(f"📁 ファイルキャッシュヒット: {cache_key[:8]}")
                return data
            
            return None
            
        except Exception as e:
            logger.warning(f"⚠️ キャッシュ読み込みエラー: {e}")
            return None
    
    async def _save_to_cache(self, cache_key: str, data: Any):
        """キャッシュに保存"""
        try:
            # メモリキャッシュに保存
            self.memory_cache[cache_key] = data
            
            # ファイルキャッシュに保存
            cache_file = self.cache_dir / f"{cache_key}.json"
            with open(cache_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            logger.debug(f"💾 キャッシュ保存完了: {cache_key[:8]}")
            
        except Exception as e:
            logger.warning(f"⚠️ キャッシュ保存エラー: {e}")
    
    def _check_rate_limit(self) -> bool:
        """レート制限チェック"""
        now = datetime.now()
        
        # 分単位リセット
        if (not self.rate_limit.last_reset_minute or 
            now.minute != self.rate_limit.last_reset_minute.minute):
            self.rate_limit.current_minute_count = 0
            self.rate_limit.last_reset_minute = now
        
        # 時間単位リセット
        if (not self.rate_limit.last_reset_hour or 
            now.hour != self.rate_limit.last_reset_hour.hour):
            self.rate_limit.current_hour_count = 0
            self.rate_limit.last_reset_hour = now
        
        # 日単位リセット
        if (not self.rate_limit.last_reset_day or 
            now.date() != self.rate_limit.last_reset_day.date()):
            self.rate_limit.current_day_count = 0
            self.rate_limit.last_reset_day = now
        
        # 制限チェック
        if self.rate_limit.current_minute_count >= self.rate_limit.requests_per_minute:
            logger.warning("⚠️ 分単位レート制限到達")
            return False
        
        if self.rate_limit.current_hour_count >= self.rate_limit.requests_per_hour:
            logger.warning("⚠️ 時間単位レート制限到達")
            return False
        
        if self.rate_limit.current_day_count >= self.rate_limit.requests_per_day:
            logger.warning("⚠️ 日単位レート制限到達")
            return False
        
        return True
    
    def _increment_rate_limit(self):
        """レート制限カウンター増加"""
        self.rate_limit.current_minute_count += 1
        self.rate_limit.current_hour_count += 1
        self.rate_limit.current_day_count += 1
    
    async def _wait_for_rate_limit(self):
        """レート制限解除待機"""
        if not self._check_rate_limit():
            # 次の分まで待機
            now = datetime.now()
            next_minute = now.replace(second=0, microsecond=0) + timedelta(minutes=1)
            wait_seconds = (next_minute - now).total_seconds()
            
            logger.info(f"⏳ レート制限解除待機: {wait_seconds:.1f}秒")
            await asyncio.sleep(wait_seconds)
    
    async def _make_request_with_retry(self, url: str, params: Dict = None, max_retries: int = 3) -> Optional[Dict]:
        """リトライ付きHTTPリクエスト実行"""
        delay = self.base_delay
        
        for attempt in range(max_retries + 1):
            try:
                # レート制限チェック
                await self._wait_for_rate_limit()
                
                # HTTPリクエスト実行
                async with self.session.get(url, params=params) as response:
                    self._increment_rate_limit()
                    
                    if response.status == 200:
                        data = await response.json()
                        logger.info(f"✅ API リクエスト成功: {url}")
                        return data
                    
                    elif response.status == 429:  # Too Many Requests
                        retry_after = int(response.headers.get('Retry-After', delay))
                        logger.warning(f"⚠️ レート制限エラー (429): {retry_after}秒待機")
                        await asyncio.sleep(retry_after)
                        continue
                    
                    elif response.status >= 500:  # Server Error
                        logger.warning(f"⚠️ サーバーエラー ({response.status}): リトライ {attempt + 1}/{max_retries}")
                        if attempt < max_retries:
                            await asyncio.sleep(delay)
                            delay = min(delay * self.backoff_factor, self.max_delay)
                            continue
                    
                    else:
                        logger.error(f"❌ API リクエストエラー ({response.status}): {url}")
                        return None
            
            except asyncio.TimeoutError:
                logger.warning(f"⚠️ タイムアウトエラー: リトライ {attempt + 1}/{max_retries}")
                if attempt < max_retries:
                    await asyncio.sleep(delay)
                    delay = min(delay * self.backoff_factor, self.max_delay)
                    continue
            
            except Exception as e:
                logger.error(f"❌ リクエストエラー: {e}")
                if attempt < max_retries:
                    await asyncio.sleep(delay)
                    delay = min(delay * self.backoff_factor, self.max_delay)
                    continue
                break
        
        logger.error(f"❌ 最大リトライ回数到達: {url}")
        return None
    
    async def fetch_with_optimization(self, url: str, params: Dict = None, force_refresh: bool = False) -> Optional[Dict]:
        """
        最適化されたAPI取得
        
        Args:
            url: 取得URL
            params: パラメータ
            force_refresh: 強制リフレッシュ
            
        Returns:
            取得データ
        """
        cache_key = self._generate_cache_key(url, params)
        
        # キャッシュ確認（強制リフレッシュでない場合）
        if not force_refresh:
            cached_data = await self._load_from_cache(cache_key)
            if cached_data:
                return cached_data
        
        # API リクエスト実行
        data = await self._make_request_with_retry(url, params)
        
        if data:
            # キャッシュに保存
            await self._save_to_cache(cache_key, data)
        
        return data
    
    async def batch_fetch(self, requests: List[Dict], max_concurrent: int = 5) -> List[Optional[Dict]]:
        """
        バッチ取得（並行処理）
        
        Args:
            requests: リクエストリスト [{"url": str, "params": dict}, ...]
            max_concurrent: 最大並行数
            
        Returns:
            取得結果リスト
        """
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def fetch_with_semaphore(request_data: Dict) -> Optional[Dict]:
            async with semaphore:
                return await self.fetch_with_optimization(
                    request_data["url"],
                    request_data.get("params")
                )
        
        # 並行実行
        tasks = [fetch_with_semaphore(req) for req in requests]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # 例外を None に変換
        processed_results = []
        for result in results:
            if isinstance(result, Exception):
                logger.error(f"❌ バッチ処理エラー: {result}")
                processed_results.append(None)
            else:
                processed_results.append(result)
        
        success_count = sum(1 for r in processed_results if r is not None)
        logger.info(f"📊 バッチ処理完了: {success_count}/{len(requests)} 成功")
        
        return processed_results
    
    def get_rate_limit_status(self) -> Dict[str, Any]:
        """レート制限状況取得"""
        return {
            "requests_per_minute": {
                "limit": self.rate_limit.requests_per_minute,
                "current": self.rate_limit.current_minute_count,
                "remaining": self.rate_limit.requests_per_minute - self.rate_limit.current_minute_count
            },
            "requests_per_hour": {
                "limit": self.rate_limit.requests_per_hour,
                "current": self.rate_limit.current_hour_count,
                "remaining": self.rate_limit.requests_per_hour - self.rate_limit.current_hour_count
            },
            "requests_per_day": {
                "limit": self.rate_limit.requests_per_day,
                "current": self.rate_limit.current_day_count,
                "remaining": self.rate_limit.requests_per_day - self.rate_limit.current_day_count
            },
            "last_resets": {
                "minute": self.rate_limit.last_reset_minute.isoformat() if self.rate_limit.last_reset_minute else None,
                "hour": self.rate_limit.last_reset_hour.isoformat() if self.rate_limit.last_reset_hour else None,
                "day": self.rate_limit.last_reset_day.isoformat() if self.rate_limit.last_reset_day else None
            }
        }
    
    def clear_cache(self, pattern: Optional[str] = None):
        """キャッシュクリア"""
        try:
            # メモリキャッシュクリア
            if pattern:
                keys_to_remove = [k for k in self.memory_cache.keys() if pattern in k]
                for key in keys_to_remove:
                    del self.memory_cache[key]
            else:
                self.memory_cache.clear()
            
            # ファイルキャッシュクリア
            cache_files = list(self.cache_dir.glob("*.json"))
            if pattern:
                cache_files = [f for f in cache_files if pattern in f.name]
            
            for cache_file in cache_files:
                cache_file.unlink()
            
            logger.info(f"🗑️ キャッシュクリア完了: {len(cache_files)}ファイル")
            
        except Exception as e:
            logger.error(f"❌ キャッシュクリアエラー: {e}")

# Context7専用最適化クライアント
class Context7OptimizedClient:
    """Context7専用最適化クライアント"""
    
    def __init__(self):
        self.optimizer = Context7APIOptimizer()
        self.base_url = "https://api.context7.com"  # 仮のURL
    
    async def resolve_library_id(self, library_name: str) -> Optional[Dict]:
        """ライブラリID解決（最適化版）"""
        url = f"{self.base_url}/resolve"
        params = {"library_name": library_name}
        
        async with self.optimizer:
            return await self.optimizer.fetch_with_optimization(url, params)
    
    async def get_library_docs(self, library_id: str, topic: str = None, tokens: int = 8000) -> Optional[Dict]:
        """ライブラリドキュメント取得（最適化版）"""
        url = f"{self.base_url}/docs"
        params = {
            "library_id": library_id,
            "topic": topic,
            "tokens": tokens
        }
        
        async with self.optimizer:
            return await self.optimizer.fetch_with_optimization(url, params)
    
    async def batch_resolve_libraries(self, library_names: List[str]) -> List[Optional[Dict]]:
        """複数ライブラリID一括解決"""
        requests = [
            {"url": f"{self.base_url}/resolve", "params": {"library_name": name}}
            for name in library_names
        ]
        
        async with self.optimizer:
            return await self.optimizer.batch_fetch(requests, max_concurrent=3)

# 使用例とテスト
async def test_context7_optimization():
    """Context7最適化テスト"""
    print("🧪 Context7 API最適化テスト開始")
    
    client = Context7OptimizedClient()
    
    # 単一リクエストテスト
    result = await client.resolve_library_id("PyQt6")
    print(f"📋 単一リクエスト結果: {result is not None}")
    
    # バッチリクエストテスト
    libraries = ["PyQt6", "FastAPI", "Microsoft Graph SDK"]
    batch_results = await client.batch_resolve_libraries(libraries)
    success_count = sum(1 for r in batch_results if r is not None)
    print(f"📊 バッチリクエスト結果: {success_count}/{len(libraries)}")
    
    # レート制限状況確認
    async with client.optimizer:
        status = client.optimizer.get_rate_limit_status()
        print(f"📈 レート制限状況: {status}")

if __name__ == "__main__":
    asyncio.run(test_context7_optimization())