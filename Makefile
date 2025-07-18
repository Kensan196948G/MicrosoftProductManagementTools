# Microsoft 365管理ツール - Makefile
# Dev1 - Test/QA Developer による基盤構築

.PHONY: help install test test-unit test-integration test-compatibility test-gui test-all clean lint format security docs

# デフォルトターゲット
help:
	@echo "Microsoft 365管理ツール - 開発用コマンド"
	@echo ""
	@echo "利用可能なコマンド:"
	@echo "  install           - 依存関係インストール"
	@echo "  test             - 全テスト実行"
	@echo "  test-unit        - ユニットテスト実行"
	@echo "  test-integration - 統合テスト実行"
	@echo "  test-compatibility - 互換性テスト実行"
	@echo "  test-gui         - GUIテスト実行"
	@echo "  test-all         - 包括的テスト実行（レポート付き）"
	@echo "  lint             - コード品質チェック"
	@echo "  format           - コードフォーマット"
	@echo "  security         - セキュリティスキャン"
	@echo "  clean            - 一時ファイル削除"
	@echo "  docs             - ドキュメント生成"

# 依存関係インストール
install:
	@echo "📦 依存関係インストール中..."
	python -m pip install --upgrade pip
	pip install -r requirements.txt
	pip install -e .
	@echo "✅ インストール完了"

# テスト実行
test:
	@echo "🧪 基本テスト実行中..."
	python -m pytest tests/ -v --tb=short -m "not slow and not requires_auth"

test-unit:
	@echo "🧪 ユニットテスト実行中..."
	python -m pytest tests/unit -v --tb=short --cov=src --cov-report=html

test-integration:
	@echo "🔗 統合テスト実行中..."
	python -m pytest tests/integration -v --tb=short -m "not requires_auth"

test-compatibility:
	@echo "🤝 互換性テスト実行中..."
	python -m pytest tests/compatibility -v --tb=short -m "not requires_powershell and not requires_auth"

test-gui:
	@echo "🖥️ GUIテスト実行中..."
	python -m pytest tests/ -v --tb=short -m "gui and not requires_auth"

test-all:
	@echo "🚀 包括的テスト実行中..."
	python tests/run_test_suite.py --category all --verbose --skip-powershell

# コード品質チェック
lint:
	@echo "🔍 コード品質チェック中..."
	flake8 src/ tests/ --max-line-length=100 --ignore=E501,W503
	mypy src/ --ignore-missing-imports

# コードフォーマット
format:
	@echo "✨ コードフォーマット中..."
	black src/ tests/ --line-length=100
	@echo "✅ フォーマット完了"

# セキュリティスキャン
security:
	@echo "🔒 セキュリティスキャン中..."
	bandit -r src/ -f txt
	safety check

# 一時ファイル削除
clean:
	@echo "🧹 一時ファイル削除中..."
	find . -type d -name "__pycache__" -delete
	find . -type f -name "*.pyc" -delete
	find . -type d -name ".pytest_cache" -delete
	rm -rf htmlcov/
	rm -rf .coverage
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	@echo "✅ 削除完了"

# ドキュメント生成
docs:
	@echo "📚 ドキュメント生成中..."
	python tests/run_test_suite.py --report-only
	@echo "✅ ドキュメント生成完了"

# 開発環境セットアップ
dev-setup: install
	@echo "🛠️ 開発環境セットアップ中..."
	pre-commit install
	@echo "✅ 開発環境セットアップ完了"

# CI環境テスト（GitHub Actions相当）
test-ci:
	@echo "⚙️ CI環境テスト実行中..."
	python -m pytest tests/ -v --tb=short \
		--cov=src --cov-report=xml --cov-report=html \
		--junitxml=test-results.xml \
		--html=test-report.html --self-contained-html \
		-m "not requires_auth and not requires_powershell"

# パフォーマンステスト
test-performance:
	@echo "⚡ パフォーマンステスト実行中..."
	python -m pytest tests/ -v --tb=short -m "performance"

# Windows特化テスト
test-windows:
	@echo "🪟 Windows特化テスト実行中..."
	python -m pytest tests/ -v --tb=short -m "not requires_auth"

# 認証テスト（認証情報が設定されている場合のみ）
test-auth:
	@echo "🔐 認証テスト実行中..."
	python -m pytest tests/ -v --tb=short -m "requires_auth" --auth

# PowerShell互換性テスト（PowerShellが利用可能な場合のみ）
test-powershell:
	@echo "⚡ PowerShell互換性テスト実行中..."
	python -m pytest tests/compatibility -v --tb=short -m "requires_powershell" --powershell