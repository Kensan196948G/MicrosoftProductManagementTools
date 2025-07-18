import React, { useState } from 'react';
import {
  Card,
  CardContent,
  CardActions,
  Typography,
  Button,
  Box,
  Chip,
  IconButton,
  Tooltip,
  CircularProgress,
  useTheme
} from '@mui/material';
import {
  PlayArrow as PlayArrowIcon,
  Schedule as ScheduleIcon,
  Info as InfoIcon,
  Download as DownloadIcon
} from '@mui/icons-material';
import { FunctionConfig, ReportData } from '@types/index';

interface FunctionCardProps {
  config: FunctionConfig;
  onExecute: (functionId: string, reportType: string) => void;
  isExecuting?: boolean;
  lastReport?: ReportData;
  elevation?: number;
}

export const FunctionCard: React.FC<FunctionCardProps> = ({
  config,
  onExecute,
  isExecuting = false,
  lastReport,
  elevation = 2
}) => {
  const theme = useTheme();
  const [isHovered, setIsHovered] = useState(false);

  const handleExecute = () => {
    if (!isExecuting && config.isEnabled) {
      onExecute(config.id, config.reportType);
    }
  };

  const getStatusColor = () => {
    if (!config.isEnabled) return 'disabled';
    if (isExecuting) return 'info';
    if (lastReport?.status === 'completed') return 'success';
    if (lastReport?.status === 'failed') return 'error';
    return 'default';
  };

  const getStatusText = () => {
    if (!config.isEnabled) return 'Disabled';
    if (isExecuting) return 'Processing...';
    if (lastReport?.status === 'completed') return 'Completed';
    if (lastReport?.status === 'failed') return 'Failed';
    return 'Ready';
  };

  return (
    <Card
      elevation={isHovered ? elevation + 2 : elevation}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        transition: 'all 0.2s ease-in-out',
        transform: isHovered ? 'translateY(-2px)' : 'translateY(0)',
        cursor: config.isEnabled ? 'pointer' : 'default',
        opacity: config.isEnabled ? 1 : 0.7,
        border: `1px solid ${theme.palette.divider}`,
        '&:hover': {
          borderColor: config.isEnabled ? theme.palette.primary.main : theme.palette.divider,
        }
      }}
    >
      <CardContent sx={{ flex: 1, p: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2, mb: 2 }}>
          <Box 
            sx={{ 
              color: theme.palette.primary.main,
              display: 'flex',
              alignItems: 'center',
              fontSize: '1.5rem'
            }}
          >
            {config.icon}
          </Box>
          
          <Box sx={{ flex: 1 }}>
            <Typography 
              variant="h6" 
              component="h3"
              sx={{ 
                fontWeight: 600,
                mb: 1,
                lineHeight: 1.2,
                color: config.isEnabled ? 'text.primary' : 'text.disabled'
              }}
            >
              {config.title}
            </Typography>
            
            <Typography 
              variant="body2" 
              color="text.secondary"
              sx={{ 
                mb: 2,
                lineHeight: 1.4,
                display: '-webkit-box',
                WebkitLineClamp: 2,
                WebkitBoxOrient: 'vertical',
                overflow: 'hidden'
              }}
            >
              {config.description}
            </Typography>
          </Box>

          <Tooltip title="More information">
            <IconButton size="small" sx={{ alignSelf: 'flex-start' }}>
              <InfoIcon fontSize="small" />
            </IconButton>
          </Tooltip>
        </Box>

        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip
            label={getStatusText()}
            size="small"
            color={getStatusColor()}
            variant="outlined"
            sx={{ fontWeight: 500 }}
          />
          
          <Chip
            icon={<ScheduleIcon />}
            label={config.estimatedTime}
            size="small"
            variant="outlined"
            sx={{ fontWeight: 500 }}
          />
        </Box>

        {lastReport && (
          <Box sx={{ mt: 2, p: 1, bgcolor: 'action.hover', borderRadius: 1 }}>
            <Typography variant="caption" color="text.secondary">
              Last run: {new Date(lastReport.createdDate).toLocaleString()}
            </Typography>
            <Typography variant="caption" display="block" color="text.secondary">
              {lastReport.dataRows} rows • {lastReport.fileSize}
            </Typography>
          </Box>
        )}
      </CardContent>

      <CardActions sx={{ p: 2, pt: 0, gap: 1 }}>
        <Button
          variant="contained"
          startIcon={
            isExecuting ? (
              <CircularProgress size={16} color="inherit" />
            ) : (
              <PlayArrowIcon />
            )
          }
          onClick={handleExecute}
          disabled={!config.isEnabled || isExecuting}
          fullWidth
          sx={{
            fontWeight: 500,
            textTransform: 'none'
          }}
        >
          {isExecuting ? 'Processing...' : 'Execute'}
        </Button>

        {lastReport?.downloadUrl && (
          <Tooltip title="Download last report">
            <IconButton
              size="small"
              color="primary"
              onClick={() => window.open(lastReport.downloadUrl, '_blank')}
            >
              <DownloadIcon />
            </IconButton>
          </Tooltip>
        )}
      </CardActions>
    </Card>
  );
};

export default FunctionCard;