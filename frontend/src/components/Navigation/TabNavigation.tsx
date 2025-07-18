import React from 'react';
import {
  Box,
  Tabs,
  Tab,
  Badge,
  useTheme,
  useMediaQuery
} from '@mui/material';
import {
  Assessment as AssessmentIcon,
  Analytics as AnalyticsIcon,
  People as PeopleIcon,
  Email as EmailIcon,
  Groups as GroupsIcon,
  CloudQueue as CloudQueueIcon
} from '@mui/icons-material';
import { TabConfig } from '@types/index';

interface TabNavigationProps {
  currentTab: string;
  onTabChange: (tabId: string) => void;
  tabs: TabConfig[];
  processingCounts?: Record<string, number>;
}

export const TabNavigation: React.FC<TabNavigationProps> = ({
  currentTab,
  onTabChange,
  tabs,
  processingCounts = {}
}) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  const handleTabChange = (_event: React.SyntheticEvent, newValue: string) => {
    onTabChange(newValue);
  };

  const getTabIcon = (tabId: string) => {
    const iconMap: Record<string, React.ReactElement> = {
      'regular-reports': <AssessmentIcon />,
      'analytics': <AnalyticsIcon />,
      'entra-id': <PeopleIcon />,
      'exchange': <EmailIcon />,
      'teams': <GroupsIcon />,
      'onedrive': <CloudQueueIcon />
    };
    
    return iconMap[tabId] || <AssessmentIcon />;
  };

  return (
    <Box
      sx={{
        borderBottom: 1,
        borderColor: 'divider',
        bgcolor: 'background.paper',
        position: 'sticky',
        top: 64,
        zIndex: 1000,
        boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)'
      }}
    >
      <Tabs
        value={currentTab}
        onChange={handleTabChange}
        variant={isMobile ? 'scrollable' : 'standard'}
        scrollButtons="auto"
        allowScrollButtonsMobile
        sx={{
          minHeight: 48,
          '& .MuiTabs-flexContainer': {
            justifyContent: isMobile ? 'flex-start' : 'center'
          }
        }}
      >
        {tabs.map((tab) => (
          <Tab
            key={tab.id}
            value={tab.id}
            label={
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                {getTabIcon(tab.id)}
                <Box sx={{ display: { xs: 'none', sm: 'block' } }}>
                  {tab.label}
                </Box>
                {processingCounts[tab.id] && processingCounts[tab.id] > 0 && (
                  <Badge 
                    badgeContent={processingCounts[tab.id]} 
                    color="primary"
                    sx={{ ml: 1 }}
                  />
                )}
              </Box>
            }
            sx={{
              minHeight: 48,
              textTransform: 'none',
              fontWeight: 500,
              color: currentTab === tab.id ? tab.color : 'text.primary',
              '&:hover': {
                bgcolor: 'action.hover'
              },
              '&.Mui-selected': {
                color: tab.color,
                fontWeight: 600
              }
            }}
          />
        ))}
      </Tabs>
    </Box>
  );
};

export default TabNavigation;