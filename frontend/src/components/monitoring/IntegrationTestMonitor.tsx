// Microsoft 365 Management Tools - 統合テスト監視コンポーネント
// リアルタイム品質監視・テストカバレッジ・パフォーマンス分析

import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useIntegrationApi } from '../../services/integrationApi';
import { IntegrationTestResponse, PerformanceMetrics } from '../../services/integrationApi';
import { toast } from 'react-hot-toast';

interface TestMetrics {
  totalTests: number;
  passedTests: number;
  failedTests: number;
  skippedTests: number;
  coverage: number;
  duration: number;
  performance: PerformanceMetrics | null;
}

interface QualityThresholds {
  coverage: number;
  performance: number;
  reliability: number;
  accessibility: number;
}

export const IntegrationTestMonitor: React.FC = () => {
  const [isRunning, setIsRunning] = useState(false);
  const [currentTest, setCurrentTest] = useState<IntegrationTestResponse | null>(null);
  const [metrics, setMetrics] = useState<TestMetrics | null>(null);
  const [qualityScore, setQualityScore] = useState<number>(0);
  const [thresholds] = useState<QualityThresholds>({
    coverage: 85,     // 85%以上
    performance: 2000, // 2秒以内
    reliability: 95,   // 95%以上
    accessibility: 100 // 100%準拠
  });

  const {
    runAll26FeaturesTest,
    runCategoryTest,
    getIntegrationTestStatus,
    monitorPerformance,
    watchIntegrationTest,
    checkApiConnectivity,
    verifyBackendIntegration
  } = useIntegrationApi();

  // 26機能統合テスト実行
  const handleRunAllTests = useCallback(async () => {
    try {
      setIsRunning(true);
      toast.info('26機能統合テスト開始...');
      
      const testResponse = await runAll26FeaturesTest();
      setCurrentTest(testResponse);
      
      // リアルタイム監視開始
      watchIntegrationTest(testResponse.testId, (updatedStatus) => {
        setCurrentTest(updatedStatus);
        updateMetrics(updatedStatus);
        
        if (updatedStatus.status === 'completed') {
          setIsRunning(false);
          toast.success('26機能統合テスト完了');
          calculateQualityScore(updatedStatus);
        } else if (updatedStatus.status === 'failed') {
          setIsRunning(false);
          toast.error('統合テストでエラーが発生しました');
        }
      });
      
    } catch (error: any) {
      setIsRunning(false);
      toast.error(`統合テスト実行失敗: ${error.message}`);
    }
  }, [runAll26FeaturesTest, watchIntegrationTest]);

  // カテゴリ別テスト実行
  const handleRunCategoryTest = useCallback(async (category: string) => {
    try {
      setIsRunning(true);
      toast.info(`${category}カテゴリテスト開始...`);
      
      const testResponse = await runCategoryTest(category as any);
      setCurrentTest(testResponse);
      
      watchIntegrationTest(testResponse.testId, (updatedStatus) => {
        setCurrentTest(updatedStatus);
        updateMetrics(updatedStatus);
        
        if (updatedStatus.status === 'completed' || updatedStatus.status === 'failed') {
          setIsRunning(false);
        }
      });
      
    } catch (error: any) {
      setIsRunning(false);
      toast.error(`カテゴリテスト実行失敗: ${error.message}`);
    }
  }, [runCategoryTest, watchIntegrationTest]);

  // メトリクス更新
  const updateMetrics = useCallback((testResponse: IntegrationTestResponse) => {
    const backendResults = testResponse.results.backend;
    const frontendResults = testResponse.results.frontend;
    const integrationResults = testResponse.results.integration;
    
    const totalTests = 
      backendResults.passed + backendResults.failed + backendResults.skipped +
      frontendResults.passed + frontendResults.failed + frontendResults.skipped +
      integrationResults.passed + integrationResults.failed + integrationResults.skipped;
    
    const passedTests = 
      backendResults.passed + frontendResults.passed + integrationResults.passed;
    
    const failedTests = 
      backendResults.failed + frontendResults.failed + integrationResults.failed;
    
    const skippedTests = 
      backendResults.skipped + frontendResults.skipped + integrationResults.skipped;
    
    const averageCoverage = 
      (backendResults.coverage + frontendResults.coverage + integrationResults.coverage) / 3;
    
    const totalDuration = 
      backendResults.duration + frontendResults.duration + integrationResults.duration;
    
    setMetrics({
      totalTests,
      passedTests,
      failedTests,
      skippedTests,
      coverage: Math.round(averageCoverage),
      duration: totalDuration,
      performance: testResponse.metrics.performance
    });
  }, []);

  // 品質スコア計算
  const calculateQualityScore = useCallback((testResponse: IntegrationTestResponse) => {
    const backendResults = testResponse.results.backend;
    const frontendResults = testResponse.results.frontend;
    const integrationResults = testResponse.results.integration;
    
    // 成功率
    const totalTests = 
      (backendResults.passed + backendResults.failed) +
      (frontendResults.passed + frontendResults.failed) +
      (integrationResults.passed + integrationResults.failed);
    
    const passedTests = 
      backendResults.passed + frontendResults.passed + integrationResults.passed;
    
    const successRate = totalTests > 0 ? (passedTests / totalTests) * 100 : 0;
    
    // カバレッジ率
    const averageCoverage = 
      (backendResults.coverage + frontendResults.coverage + integrationResults.coverage) / 3;
    
    // パフォーマンススコア
    const avgResponseTime = testResponse.metrics.performance.averageResponseTime;
    const performanceScore = Math.max(0, 100 - (avgResponseTime / thresholds.performance) * 100);
    
    // 総合品質スコア
    const overallScore = (successRate * 0.4) + (averageCoverage * 0.3) + (performanceScore * 0.3);
    
    setQualityScore(Math.round(overallScore));
  }, [thresholds.performance]);

  // 品質ステータス取得
  const getQualityStatus = useCallback((score: number) => {
    if (score >= 90) return { status: 'excellent', color: '#28a745', label: '優秀' };
    if (score >= 80) return { status: 'good', color: '#20c997', label: '良好' };
    if (score >= 70) return { status: 'fair', color: '#ffc107', label: '普通' };
    return { status: 'poor', color: '#dc3545', label: '要改善' };
  }, []);

  // バックエンド統合確認
  const handleVerifyBackend = useCallback(async () => {
    try {
      const verification = await verifyBackendIntegration();
      
      const results = Object.entries(verification).map(([key, value]) => 
        `${key}: ${value ? '✅' : '❌'}`
      ).join(', ');
      
      toast.info(`バックエンド統合状況: ${results}`);
    } catch (error: any) {
      toast.error(`バックエンド統合確認失敗: ${error.message}`);
    }
  }, [verifyBackendIntegration]);

  const qualityStatus = getQualityStatus(qualityScore);

  return (
    <div className="integration-test-monitor p-6 bg-white rounded-lg shadow-lg">
      {/* ヘッダー */}
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold text-gray-800">
          🧪 統合テスト監視ダッシュボード
        </h2>
        <div className="flex space-x-3">
          <button
            onClick={handleRunAllTests}
            disabled={isRunning}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isRunning ? '実行中...' : '26機能統合テスト実行'}
          </button>
          <button
            onClick={handleVerifyBackend}
            className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
          >
            バックエンド確認
          </button>
        </div>
      </div>

      {/* 品質スコア */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-gradient-to-r from-blue-500 to-purple-600 text-white p-4 rounded-lg">
          <h3 className="text-sm font-medium">総合品質スコア</h3>
          <div className="flex items-center mt-2">
            <span className="text-3xl font-bold">{qualityScore}</span>
            <span className="text-sm ml-2">/ 100</span>
          </div>
          <div className="mt-2">
            <span 
              className="text-xs px-2 py-1 rounded-full"
              style={{ backgroundColor: qualityStatus.color }}
            >
              {qualityStatus.label}
            </span>
          </div>
        </div>

        {metrics && (
          <>
            <div className="bg-green-50 border border-green-200 p-4 rounded-lg">
              <h3 className="text-sm font-medium text-green-800">テスト成功率</h3>
              <div className="text-2xl font-bold text-green-600 mt-2">
                {Math.round((metrics.passedTests / metrics.totalTests) * 100)}%
              </div>
              <div className="text-xs text-green-600 mt-1">
                {metrics.passedTests}/{metrics.totalTests} 成功
              </div>
            </div>

            <div className="bg-blue-50 border border-blue-200 p-4 rounded-lg">
              <h3 className="text-sm font-medium text-blue-800">カバレッジ</h3>
              <div className="text-2xl font-bold text-blue-600 mt-2">
                {metrics.coverage}%
              </div>
              <div className="text-xs text-blue-600 mt-1">
                目標: {thresholds.coverage}%
              </div>
            </div>

            <div className="bg-purple-50 border border-purple-200 p-4 rounded-lg">
              <h3 className="text-sm font-medium text-purple-800">実行時間</h3>
              <div className="text-2xl font-bold text-purple-600 mt-2">
                {Math.round(metrics.duration / 1000)}s
              </div>
              {metrics.performance && (
                <div className="text-xs text-purple-600 mt-1">
                  平均: {metrics.performance.averageResponseTime}ms
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {/* カテゴリ別テスト */}
      <div className="mb-6">
        <h3 className="text-lg font-semibold mb-3">カテゴリ別テスト実行</h3>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          {[
            { id: 'regularReports', name: '📊 定期レポート', count: 5 },
            { id: 'analyticsReports', name: '🔍 分析レポート', count: 5 },
            { id: 'entraId', name: '👥 Entra ID', count: 4 },
            { id: 'exchange', name: '📧 Exchange', count: 4 },
            { id: 'teams', name: '💬 Teams', count: 4 },
            { id: 'oneDrive', name: '💾 OneDrive', count: 4 }
          ].map((category) => (
            <button
              key={category.id}
              onClick={() => handleRunCategoryTest(category.id)}
              disabled={isRunning}
              className="p-3 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 text-left"
            >
              <div className="font-medium">{category.name}</div>
              <div className="text-sm text-gray-600">{category.count}機能</div>
            </button>
          ))}
        </div>
      </div>

      {/* 現在のテスト状況 */}
      <AnimatePresence>
        {currentTest && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="bg-gray-50 border border-gray-200 rounded-lg p-4"
          >
            <h3 className="text-lg font-semibold mb-3">
              現在のテスト状況: {currentTest.status}
            </h3>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Backend Results */}
              <div className="bg-white p-3 rounded-lg">
                <h4 className="font-medium text-gray-700 mb-2">🐍 Backend (pytest)</h4>
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span>成功:</span>
                    <span className="text-green-600 font-medium">
                      {currentTest.results.backend.passed}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>失敗:</span>
                    <span className="text-red-600 font-medium">
                      {currentTest.results.backend.failed}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>カバレッジ:</span>
                    <span className="font-medium">
                      {currentTest.results.backend.coverage}%
                    </span>
                  </div>
                </div>
              </div>

              {/* Frontend Results */}
              <div className="bg-white p-3 rounded-lg">
                <h4 className="font-medium text-gray-700 mb-2">🌐 Frontend (E2E)</h4>
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span>成功:</span>
                    <span className="text-green-600 font-medium">
                      {currentTest.results.frontend.passed}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>失敗:</span>
                    <span className="text-red-600 font-medium">
                      {currentTest.results.frontend.failed}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>カバレッジ:</span>
                    <span className="font-medium">
                      {currentTest.results.frontend.coverage}%
                    </span>
                  </div>
                </div>
              </div>

              {/* Integration Results */}
              <div className="bg-white p-3 rounded-lg">
                <h4 className="font-medium text-gray-700 mb-2">🔗 統合テスト</h4>
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span>成功:</span>
                    <span className="text-green-600 font-medium">
                      {currentTest.results.integration.passed}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>失敗:</span>
                    <span className="text-red-600 font-medium">
                      {currentTest.results.integration.failed}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>カバレッジ:</span>
                    <span className="font-medium">
                      {currentTest.results.integration.coverage}%
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* パフォーマンスメトリクス */}
            {currentTest.metrics.performance && (
              <div className="mt-4 bg-white p-3 rounded-lg">
                <h4 className="font-medium text-gray-700 mb-2">⚡ パフォーマンス</h4>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
                  <div>
                    <span className="text-gray-600">平均応答時間:</span>
                    <div className="font-medium">
                      {currentTest.metrics.performance.averageResponseTime}ms
                    </div>
                  </div>
                  <div>
                    <span className="text-gray-600">最大応答時間:</span>
                    <div className="font-medium">
                      {currentTest.metrics.performance.maxResponseTime}ms
                    </div>
                  </div>
                  <div>
                    <span className="text-gray-600">最小応答時間:</span>
                    <div className="font-medium">
                      {currentTest.metrics.performance.minResponseTime}ms
                    </div>
                  </div>
                  <div>
                    <span className="text-gray-600">スループット:</span>
                    <div className="font-medium">
                      {currentTest.metrics.performance.throughput} req/s
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* エラー詳細 */}
            {currentTest.results.backend.errors.length > 0 && (
              <div className="mt-4 bg-red-50 border border-red-200 p-3 rounded-lg">
                <h4 className="font-medium text-red-800 mb-2">🚨 エラー詳細</h4>
                <div className="text-sm space-y-1">
                  {currentTest.results.backend.errors.slice(0, 3).map((error, index) => (
                    <div key={index} className="text-red-700">
                      • {error}
                    </div>
                  ))}
                  {currentTest.results.backend.errors.length > 3 && (
                    <div className="text-red-600">
                      ...他 {currentTest.results.backend.errors.length - 3} 件
                    </div>
                  )}
                </div>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {/* 実行中インジケーター */}
      {isRunning && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg shadow-xl text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-4 border-blue-500 border-t-transparent mx-auto mb-4"></div>
            <div className="text-lg font-medium">統合テスト実行中...</div>
            <div className="text-sm text-gray-600 mt-2">
              pytest + Cypress + Playwright 統合実行
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default IntegrationTestMonitor;