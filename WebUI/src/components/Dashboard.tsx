import React, { useState, useEffect } from 'react';
import {
  Box,
  Container,
  Grid,
  Paper,
  Typography,
  Card,
  CardContent,
  CardActions,
  Button,
  Chip,
  LinearProgress,
  IconButton,
  Drawer,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  AppBar,
  Toolbar,
  useTheme,
  useMediaQuery
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  Assessment,
  People,
  Email,
  Chat,
  CloudQueue,
  Menu as MenuIcon,
  PlayArrow,
  GetApp
} from '@mui/icons-material';

interface FeatureCategory {
  id: string;
  title: string;
  icon: React.ReactNode;
  color: string;
  features: Feature[];
}

interface Feature {
  id: string;
  name: string;
  description: string;
  lastRun?: string;
  status?: 'ready' | 'running' | 'completed' | 'error';
}

const Dashboard: React.FC = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const isTablet = useMediaQuery(theme.breakpoints.down('md'));
  
  const [drawerOpen, setDrawerOpen] = useState(!isMobile);
  const [selectedCategory, setSelectedCategory] = useState<string>('regular');
  const [runningFeatures, setRunningFeatures] = useState<Set<string>>(new Set());

  const categories: FeatureCategory[] = [
    {
      id: 'regular',
      title: '📊 定期レポート',
      icon: <DashboardIcon />,
      color: '#2196F3',
      features: [
        { id: 'daily', name: '📅 日次レポート', description: '日次のログイン状況・容量監視' },
        { id: 'weekly', name: '📊 週次レポート', description: '週次のMFA状況・外部共有' },
        { id: 'monthly', name: '📈 月次レポート', description: '月次の利用率・権限レビュー' },
        { id: 'yearly', name: '📆 年次レポート', description: '年次のライセンス消費・統計' },
        { id: 'test', name: '🧪 テスト実行', description: 'レポート機能のテスト実行' }
      ]
    },
    {
      id: 'analysis',
      title: '🔍 分析レポート',
      icon: <Assessment />,
      color: '#4CAF50',
      features: [
        { id: 'license', name: '📊 ライセンス分析', description: 'ライセンス使用状況とコスト分析' },
        { id: 'usage', name: '📈 使用状況分析', description: 'サービス別の使用状況分析' },
        { id: 'performance', name: '⚡ パフォーマンス分析', description: 'システムパフォーマンス監視' },
        { id: 'security', name: '🛡️ セキュリティ分析', description: 'セキュリティリスクの分析' },
        { id: 'permission', name: '🔍 権限監査', description: 'アクセス権限の監査レポート' }
      ]
    },
    {
      id: 'entraid',
      title: '👥 Entra ID管理',
      icon: <People />,
      color: '#FF9800',
      features: [
        { id: 'users', name: '👥 ユーザー一覧', description: '全ユーザーの一覧表示' },
        { id: 'mfa', name: '🔐 MFA状況', description: '多要素認証の設定状況' },
        { id: 'conditional', name: '🛡️ 条件付きアクセス', description: '条件付きアクセスポリシー' },
        { id: 'signin', name: '📝 サインインログ', description: 'サインインアクティビティ' }
      ]
    },
    {
      id: 'exchange',
      title: '📧 Exchange Online',
      icon: <Email />,
      color: '#9C27B0',
      features: [
        { id: 'mailbox', name: '📧 メールボックス管理', description: 'メールボックスの管理' },
        { id: 'mailflow', name: '🔄 メールフロー分析', description: 'メールフローの分析' },
        { id: 'spam', name: '🛡️ スパム対策分析', description: 'スパム対策の状況' },
        { id: 'delivery', name: '📬 配信分析', description: 'メール配信の分析' }
      ]
    },
    {
      id: 'teams',
      title: '💬 Teams管理',
      icon: <Chat />,
      color: '#00BCD4',
      features: [
        { id: 'teams-usage', name: '💬 Teams使用状況', description: 'Teamsの利用状況' },
        { id: 'teams-settings', name: '⚙️ Teams設定分析', description: 'Teams設定の分析' },
        { id: 'meeting', name: '📹 会議品質分析', description: '会議の品質分析' },
        { id: 'apps', name: '📱 アプリ分析', description: 'Teamsアプリの利用状況' }
      ]
    },
    {
      id: 'onedrive',
      title: '💾 OneDrive管理',
      icon: <CloudQueue />,
      color: '#607D8B',
      features: [
        { id: 'storage', name: '💾 ストレージ分析', description: 'ストレージ使用状況' },
        { id: 'sharing', name: '🤝 共有分析', description: 'ファイル共有の分析' },
        { id: 'sync', name: '🔄 同期エラー分析', description: '同期エラーの分析' },
        { id: 'external', name: '🌐 外部共有分析', description: '外部共有の状況' }
      ]
    }
  ];

  const handleRunFeature = async (categoryId: string, featureId: string) => {
    setRunningFeatures(prev => new Set(prev).add(`${categoryId}-${featureId}`));
    
    try {
      const response = await fetch(`/api/features/${categoryId}/${featureId}/run`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      
      if (response.ok) {
        // WebSocketでリアルタイムログを受信する処理をここに追加
        console.log(`Feature ${featureId} started successfully`);
      }
    } catch (error) {
      console.error('Failed to run feature:', error);
    } finally {
      setTimeout(() => {
        setRunningFeatures(prev => {
          const newSet = new Set(prev);
          newSet.delete(`${categoryId}-${featureId}`);
          return newSet;
        });
      }, 5000);
    }
  };

  const selectedCategoryData = categories.find(cat => cat.id === selectedCategory);

  return (
    <Box sx={{ display: 'flex', height: '100vh' }}>
      <AppBar position="fixed" sx={{ zIndex: theme.zIndex.drawer + 1 }}>
        <Toolbar>
          <IconButton
            color="inherit"
            edge="start"
            onClick={() => setDrawerOpen(!drawerOpen)}
            sx={{ mr: 2 }}
          >
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
            🚀 Microsoft 365 統合管理ツール
          </Typography>
          <Chip 
            label="接続済み" 
            color="success" 
            size="small"
            sx={{ mr: 2 }}
          />
        </Toolbar>
      </AppBar>

      <Drawer
        variant={isMobile ? "temporary" : "persistent"}
        anchor="left"
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        sx={{
          width: drawerOpen ? 240 : 0,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: 240,
            boxSizing: 'border-box',
            mt: 8
          },
        }}
      >
        <List>
          {categories.map((category) => (
            <ListItem 
              button 
              key={category.id}
              selected={selectedCategory === category.id}
              onClick={() => setSelectedCategory(category.id)}
            >
              <ListItemIcon sx={{ color: category.color }}>
                {category.icon}
              </ListItemIcon>
              <ListItemText primary={category.title} />
            </ListItem>
          ))}
        </List>
      </Drawer>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          mt: 8,
          ml: drawerOpen && !isMobile ? '240px' : 0,
          transition: theme.transitions.create(['margin'], {
            easing: theme.transitions.easing.sharp,
            duration: theme.transitions.duration.leavingScreen,
          }),
        }}
      >
        <Container maxWidth="xl">
          <Typography variant="h4" gutterBottom sx={{ mb: 4 }}>
            {selectedCategoryData?.title}
          </Typography>

          <Grid container spacing={3}>
            {selectedCategoryData?.features.map((feature) => {
              const isRunning = runningFeatures.has(`${selectedCategory}-${feature.id}`);
              
              return (
                <Grid 
                  item 
                  xs={12} 
                  sm={isTablet ? 12 : 6} 
                  md={4} 
                  lg={3}
                  key={feature.id}
                >
                  <Card 
                    sx={{ 
                      height: '100%',
                      display: 'flex',
                      flexDirection: 'column',
                      transition: 'transform 0.2s, box-shadow 0.2s',
                      '&:hover': {
                        transform: 'translateY(-4px)',
                        boxShadow: 4
                      }
                    }}
                  >
                    <CardContent sx={{ flexGrow: 1 }}>
                      <Typography variant="h6" component="h2" gutterBottom>
                        {feature.name}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {feature.description}
                      </Typography>
                      {feature.lastRun && (
                        <Typography variant="caption" display="block" sx={{ mt: 1 }}>
                          最終実行: {feature.lastRun}
                        </Typography>
                      )}
                    </CardContent>
                    {isRunning && <LinearProgress />}
                    <CardActions>
                      <Button 
                        size="small" 
                        variant="contained"
                        startIcon={<PlayArrow />}
                        onClick={() => handleRunFeature(selectedCategory, feature.id)}
                        disabled={isRunning}
                        fullWidth
                      >
                        {isRunning ? '実行中...' : '実行'}
                      </Button>
                      <IconButton size="small" title="レポートダウンロード">
                        <GetApp />
                      </IconButton>
                    </CardActions>
                  </Card>
                </Grid>
              );
            })}
          </Grid>
        </Container>
      </Box>
    </Box>
  );
};

export default Dashboard;