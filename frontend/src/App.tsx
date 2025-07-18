import React, { useState, useEffect } from 'react';
import { ThemeProvider, CssBaseline } from '@mui/material';
import { BrowserRouter as Router } from 'react-router-dom';
import { MainDashboard } from '@pages/MainDashboard/MainDashboard';
import { theme, darkTheme } from '@/theme';
import { AppState, User } from '@types/index';

// Mock user data
const mockUser: User = {
  id: 'user-123',
  displayName: 'Admin User',
  userPrincipalName: 'admin@company.com',
  mail: 'admin@company.com',
  mfaEnabled: true,
  accountEnabled: true,
  lastSignInDateTime: new Date().toISOString(),
  createdDateTime: new Date().toISOString(),
  department: 'IT',
  jobTitle: 'System Administrator',
  usageLocation: 'JP',
  assignedLicenses: []
};

function App() {
  const [appState, setAppState] = useState<AppState>({
    currentTab: 'regular-reports',
    isLoading: false,
    reports: [],
    notifications: [],
    user: mockUser,
    theme: 'light'
  });

  const handleAppStateChange = (newState: Partial<AppState>) => {
    setAppState(prev => ({ ...prev, ...newState }));
  };

  // Load theme preference from localStorage
  useEffect(() => {
    const savedTheme = localStorage.getItem('theme') as 'light' | 'dark';
    if (savedTheme) {
      setAppState(prev => ({ ...prev, theme: savedTheme }));
    }
  }, []);

  // Save theme preference to localStorage
  useEffect(() => {
    localStorage.setItem('theme', appState.theme);
  }, [appState.theme]);

  const currentTheme = appState.theme === 'light' ? theme : darkTheme;

  return (
    <ThemeProvider theme={currentTheme}>
      <CssBaseline />
      <Router>
        <MainDashboard
          appState={appState}
          onAppStateChange={handleAppStateChange}
        />
      </Router>
    </ThemeProvider>
  );
}

export default App;