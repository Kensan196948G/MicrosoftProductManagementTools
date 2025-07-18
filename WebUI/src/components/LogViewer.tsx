import React, { useState, useEffect, useRef } from 'react';
import {
  Box,
  Paper,
  Typography,
  Tab,
  Tabs,
  TextField,
  IconButton,
  Chip,
  List,
  ListItem,
  styled
} from '@mui/material';
import {
  Terminal as TerminalIcon,
  Error as ErrorIcon,
  Info as InfoIcon,
  CheckCircle as SuccessIcon,
  Warning as WarningIcon,
  Clear as ClearIcon,
  GetApp as DownloadIcon
} from '@mui/icons-material';

interface LogEntry {
  id: string;
  timestamp: string;
  level: 'info' | 'success' | 'warning' | 'error' | 'debug';
  message: string;
  source?: string;
}

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

const TabPanel: React.FC<TabPanelProps> = ({ children, value, index }) => {
  return (
    <div role="tabpanel" hidden={value !== index}>
      {value === index && <Box sx={{ p: 2 }}>{children}</Box>}
    </div>
  );
};

const ConsoleBox = styled(Box)(({ theme }) => ({
  backgroundColor: '#1e1e1e',
  color: '#d4d4d4',
  fontFamily: '"Cascadia Code", "Consolas", monospace',
  fontSize: '0.875rem',
  padding: theme.spacing(2),
  height: '100%',
  overflowY: 'auto',
  '&::-webkit-scrollbar': {
    width: '8px',
  },
  '&::-webkit-scrollbar-track': {
    backgroundColor: '#2e2e2e',
  },
  '&::-webkit-scrollbar-thumb': {
    backgroundColor: '#555',
    borderRadius: '4px',
  }
}));

const LogLine = styled('div')<{ level: string }>(({ level }) => {
  const colors = {
    info: '#3794ff',
    success: '#4ec9b0',
    warning: '#dcdcaa',
    error: '#f48771',
    debug: '#9cdcfe'
  };
  
  return {
    color: colors[level as keyof typeof colors] || '#d4d4d4',
    marginBottom: '4px',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-word'
  };
});

const LogViewer: React.FC = () => {
  const [tabValue, setTabValue] = useState(0);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [errorLogs, setErrorLogs] = useState<LogEntry[]>([]);
  const [command, setCommand] = useState('');
  const [commandHistory, setCommandHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState(-1);
  
  const logEndRef = useRef<HTMLDivElement>(null);
  const errorLogEndRef = useRef<HTMLDivElement>(null);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    // WebSocket接続
    const ws = new WebSocket('ws://localhost:3001/ws');
    wsRef.current = ws;

    ws.onopen = () => {
      console.log('WebSocket connected');
      addLog('info', 'WebSocket接続が確立されました');
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'log') {
        addLog(data.level, data.message, data.source);
      }
    };

    ws.onerror = (error) => {
      addLog('error', `WebSocket エラー: ${error}`);
    };

    ws.onclose = () => {
      addLog('warning', 'WebSocket接続が切断されました');
    };

    return () => {
      ws.close();
    };
  }, []);

  useEffect(() => {
    // 自動スクロール
    if (tabValue === 0) {
      logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    } else if (tabValue === 1) {
      errorLogEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [logs, errorLogs, tabValue]);

  const addLog = (level: LogEntry['level'], message: string, source?: string) => {
    const newEntry: LogEntry = {
      id: `${Date.now()}-${Math.random()}`,
      timestamp: new Date().toLocaleTimeString('ja-JP'),
      level,
      message,
      source
    };

    if (level === 'error') {
      setErrorLogs(prev => [...prev, newEntry]);
    }
    setLogs(prev => [...prev, newEntry]);
  };

  const handleCommand = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && command.trim()) {
      // コマンド実行
      addLog('info', `PS> ${command}`);
      setCommandHistory(prev => [...prev, command]);
      setHistoryIndex(-1);
      
      // WebSocket経由でコマンドを送信
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({
          type: 'command',
          command: command
        }));
      }
      
      setCommand('');
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (historyIndex < commandHistory.length - 1) {
        const newIndex = historyIndex + 1;
        setHistoryIndex(newIndex);
        setCommand(commandHistory[commandHistory.length - 1 - newIndex]);
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (historyIndex > 0) {
        const newIndex = historyIndex - 1;
        setHistoryIndex(newIndex);
        setCommand(commandHistory[commandHistory.length - 1 - newIndex]);
      } else if (historyIndex === 0) {
        setHistoryIndex(-1);
        setCommand('');
      }
    }
  };

  const clearLogs = () => {
    if (tabValue === 0) {
      setLogs([]);
    } else if (tabValue === 1) {
      setErrorLogs([]);
    }
  };

  const downloadLogs = () => {
    const logsToDownload = tabValue === 0 ? logs : errorLogs;
    const content = logsToDownload
      .map(log => `[${log.timestamp}] [${log.level.toUpperCase()}] ${log.message}`)
      .join('\n');
    
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `logs_${new Date().toISOString().replace(/[:.]/g, '-')}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const getIcon = (level: string) => {
    switch (level) {
      case 'info': return <InfoIcon sx={{ fontSize: 16 }} />;
      case 'success': return <SuccessIcon sx={{ fontSize: 16 }} />;
      case 'warning': return <WarningIcon sx={{ fontSize: 16 }} />;
      case 'error': return <ErrorIcon sx={{ fontSize: 16 }} />;
      default: return <TerminalIcon sx={{ fontSize: 16 }} />;
    }
  };

  return (
    <Paper sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ borderBottom: 1, borderColor: 'divider', display: 'flex', alignItems: 'center' }}>
        <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)} sx={{ flexGrow: 1 }}>
          <Tab 
            label={
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <TerminalIcon />
                詳細実行ログ
                <Chip label={logs.length} size="small" />
              </Box>
            } 
          />
          <Tab 
            label={
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <ErrorIcon />
                エラーログ
                <Chip label={errorLogs.length} size="small" color="error" />
              </Box>
            } 
          />
          <Tab 
            label={
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <TerminalIcon />
                PowerShellプロンプト
              </Box>
            } 
          />
        </Tabs>
        <IconButton onClick={clearLogs} size="small" title="ログをクリア">
          <ClearIcon />
        </IconButton>
        <IconButton onClick={downloadLogs} size="small" title="ログをダウンロード">
          <DownloadIcon />
        </IconButton>
      </Box>

      <Box sx={{ flexGrow: 1, overflow: 'hidden' }}>
        <TabPanel value={tabValue} index={0}>
          <ConsoleBox>
            {logs.map((log) => (
              <LogLine key={log.id} level={log.level}>
                <Box component="span" sx={{ opacity: 0.7 }}>
                  [{log.timestamp}]
                </Box>{' '}
                {getIcon(log.level)} {log.message}
              </LogLine>
            ))}
            <div ref={logEndRef} />
          </ConsoleBox>
        </TabPanel>

        <TabPanel value={tabValue} index={1}>
          <ConsoleBox>
            {errorLogs.map((log) => (
              <LogLine key={log.id} level={log.level}>
                <Box component="span" sx={{ opacity: 0.7 }}>
                  [{log.timestamp}]
                </Box>{' '}
                {getIcon(log.level)} {log.message}
              </LogLine>
            ))}
            <div ref={errorLogEndRef} />
          </ConsoleBox>
        </TabPanel>

        <TabPanel value={tabValue} index={2}>
          <ConsoleBox>
            {logs.filter(log => log.message.startsWith('PS>')).map((log) => (
              <LogLine key={log.id} level={log.level}>
                {log.message}
              </LogLine>
            ))}
            <Box sx={{ display: 'flex', alignItems: 'center', mt: 2 }}>
              <Typography sx={{ color: '#4ec9b0', mr: 1 }}>PS&gt;</Typography>
              <TextField
                fullWidth
                variant="standard"
                value={command}
                onChange={(e) => setCommand(e.target.value)}
                onKeyDown={handleCommand}
                sx={{
                  input: {
                    color: '#d4d4d4',
                    fontFamily: '"Cascadia Code", "Consolas", monospace',
                  }
                }}
                InputProps={{
                  disableUnderline: true,
                }}
              />
            </Box>
          </ConsoleBox>
        </TabPanel>
      </Box>
    </Paper>
  );
};

export default LogViewer;