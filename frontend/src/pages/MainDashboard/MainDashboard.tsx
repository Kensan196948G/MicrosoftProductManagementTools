import React, { useState, useEffect } from 'react';
import {
  Box,
  Container,
  Grid,
  Typography,
  Paper,
  Fade,
  Alert,
  Skeleton
} from '@mui/material';
import { AppLayout } from '@components/Layout/AppLayout';
import { TabNavigation } from '@components/Navigation/TabNavigation';
import { FunctionCard } from '@components/FunctionCard/FunctionCard';
import { tabsConfig } from '@config/tabs';
import { AppState, ReportData, Notification } from '@types/index';

interface MainDashboardProps {
  appState: AppState;
  onAppStateChange: (newState: Partial<AppState>) => void;
}

export const MainDashboard: React.FC<MainDashboardProps> = ({
  appState,
  onAppStateChange
}) => {
  const [executingFunctions, setExecutingFunctions] = useState<Set<string>>(new Set());
  const [processingCounts, setProcessingCounts] = useState<Record<string, number>>({});

  const currentTabConfig = tabsConfig.find(tab => tab.id === appState.currentTab);

  useEffect(() => {
    // Calculate processing counts for each tab
    const counts: Record<string, number> = {};
    tabsConfig.forEach(tab => {
      counts[tab.id] = tab.functions.filter(func => 
        executingFunctions.has(func.id)
      ).length;
    });
    setProcessingCounts(counts);
  }, [executingFunctions]);

  const handleTabChange = (tabId: string) => {
    onAppStateChange({ currentTab: tabId });
  };

  const handleMenuToggle = () => {
    // For mobile drawer toggle - can be implemented later
    console.log('Menu toggle');
  };

  const handleThemeToggle = () => {
    const newTheme = appState.theme === 'light' ? 'dark' : 'light';
    onAppStateChange({ theme: newTheme });
  };

  const handleNotificationRead = (notificationId: string) => {
    const updatedNotifications = appState.notifications.map(notification =>
      notification.id === notificationId
        ? { ...notification, isRead: true }
        : notification
    );
    onAppStateChange({ notifications: updatedNotifications });
  };

  const handleFunctionExecute = async (functionId: string, reportType: string) => {
    // Add to executing functions
    setExecutingFunctions(prev => new Set(prev).add(functionId));
    
    // Set loading state
    onAppStateChange({ isLoading: true });

    try {
      // Mock API call - replace with actual implementation
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Create mock report data
      const newReport: ReportData = {
        id: `report-${Date.now()}`,
        type: reportType as any,
        title: `${currentTabConfig?.functions.find(f => f.id === functionId)?.title} Report`,
        description: `Generated report for ${reportType}`,
        createdDate: new Date().toISOString(),
        status: 'completed',
        dataRows: Math.floor(Math.random() * 10000) + 100,
        fileSize: `${Math.floor(Math.random() * 10) + 1}.${Math.floor(Math.random() * 900) + 100}MB`,
        downloadUrl: '#'
      };

      // Add new report to state
      onAppStateChange({
        reports: [...appState.reports, newReport],
        isLoading: false
      });

      // Create success notification
      const successNotification: Notification = {
        id: `notification-${Date.now()}`,
        type: 'success',
        title: 'Report Generated Successfully',
        message: `${newReport.title} has been generated with ${newReport.dataRows} rows`,
        timestamp: new Date().toISOString(),
        isRead: false
      };

      onAppStateChange({
        notifications: [...appState.notifications, successNotification]
      });

    } catch (error) {
      // Create error notification
      const errorNotification: Notification = {
        id: `notification-${Date.now()}`,
        type: 'error',
        title: 'Report Generation Failed',
        message: 'An error occurred while generating the report. Please try again.',
        timestamp: new Date().toISOString(),
        isRead: false
      };

      onAppStateChange({
        notifications: [...appState.notifications, errorNotification],
        isLoading: false
      });
    } finally {
      // Remove from executing functions
      setExecutingFunctions(prev => {
        const newSet = new Set(prev);
        newSet.delete(functionId);
        return newSet;
      });
    }
  };

  const getLastReportForFunction = (functionId: string): ReportData | undefined => {
    return appState.reports
      .filter(report => report.type === currentTabConfig?.functions.find(f => f.id === functionId)?.reportType)
      .sort((a, b) => new Date(b.createdDate).getTime() - new Date(a.createdDate).getTime())[0];
  };

  if (!currentTabConfig) {
    return (
      <AppLayout
        title="Microsoft 365 Admin Tools"
        onMenuToggle={handleMenuToggle}
        onThemeToggle={handleThemeToggle}
        appState={appState}
        onNotificationRead={handleNotificationRead}
      >
        <Container maxWidth="lg">
          <Alert severity="error">
            Invalid tab configuration. Please check your settings.
          </Alert>
        </Container>
      </AppLayout>
    );
  }

  return (
    <AppLayout
      title="Microsoft 365 Admin Tools"
      onMenuToggle={handleMenuToggle}
      onThemeToggle={handleThemeToggle}
      appState={appState}
      onNotificationRead={handleNotificationRead}
    >
      <TabNavigation
        currentTab={appState.currentTab}
        onTabChange={handleTabChange}
        tabs={tabsConfig}
        processingCounts={processingCounts}
      />

      <Container maxWidth="lg" sx={{ mt: 3 }}>
        <Fade in timeout={500}>
          <Box>
            <Paper
              elevation={1}
              sx={{
                p: 3,
                mb: 4,
                bgcolor: 'background.paper',
                borderRadius: 2,
                border: `1px solid ${currentTabConfig.color}`,
                borderLeft: `4px solid ${currentTabConfig.color}`
              }}
            >
              <Typography
                variant="h4"
                component="h1"
                gutterBottom
                sx={{
                  fontWeight: 600,
                  color: currentTabConfig.color,
                  mb: 2
                }}
              >
                {currentTabConfig.label}
              </Typography>
              <Typography variant="body1" color="text.secondary">
                {currentTabConfig.functions.length} functions available • 
                {processingCounts[currentTabConfig.id] || 0} processing
              </Typography>
            </Paper>

            {appState.isLoading && (
              <Box sx={{ mb: 3 }}>
                <Grid container spacing={3}>
                  {[...Array(6)].map((_, index) => (
                    <Grid item xs={12} sm={6} md={4} key={index}>
                      <Skeleton variant="rectangular" height={200} />
                    </Grid>
                  ))}
                </Grid>
              </Box>
            )}

            <Grid container spacing={3}>
              {currentTabConfig.functions.map((functionConfig) => (
                <Grid item xs={12} sm={6} md={4} key={functionConfig.id}>
                  <Fade in timeout={500} style={{ transitionDelay: '100ms' }}>
                    <Box>
                      <FunctionCard
                        config={functionConfig}
                        onExecute={handleFunctionExecute}
                        isExecuting={executingFunctions.has(functionConfig.id)}
                        lastReport={getLastReportForFunction(functionConfig.id)}
                        elevation={2}
                      />
                    </Box>
                  </Fade>
                </Grid>
              ))}
            </Grid>
          </Box>
        </Fade>
      </Container>
    </AppLayout>
  );
};

export default MainDashboard;