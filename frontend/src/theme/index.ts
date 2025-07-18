import { createTheme, Theme } from '@mui/material/styles';

declare module '@mui/material/styles' {
  interface Theme {
    status: {
      danger: string;
      warning: string;
      success: string;
      info: string;
    };
  }
  
  interface ThemeOptions {
    status?: {
      danger?: string;
      warning?: string;
      success?: string;
      info?: string;
    };
  }
}

// Enterprise Color Palette
const colors = {
  primary: {
    main: '#0078d4',
    light: '#106ebe',
    dark: '#005a9e',
    contrastText: '#ffffff'
  },
  secondary: {
    main: '#6c757d',
    light: '#9ca3af',
    dark: '#495057',
    contrastText: '#ffffff'
  },
  success: {
    main: '#28a745',
    light: '#34ce57',
    dark: '#1e7e34',
    contrastText: '#ffffff'
  },
  warning: {
    main: '#ffc107',
    light: '#ffcd39',
    dark: '#e6ac00',
    contrastText: '#000000'
  },
  error: {
    main: '#dc3545',
    light: '#e35d6a',
    dark: '#c82333',
    contrastText: '#ffffff'
  },
  info: {
    main: '#17a2b8',
    light: '#3dd5f3',
    dark: '#117a8b',
    contrastText: '#ffffff'
  },
  grey: {
    50: '#f8f9fa',
    100: '#f1f3f4',
    200: '#e9ecef',
    300: '#dee2e6',
    400: '#ced4da',
    500: '#adb5bd',
    600: '#6c757d',
    700: '#495057',
    800: '#343a40',
    900: '#212529'
  }
};

// Enterprise Theme Configuration
export const theme: Theme = createTheme({
  palette: {
    mode: 'light',
    primary: colors.primary,
    secondary: colors.secondary,
    success: colors.success,
    warning: colors.warning,
    error: colors.error,
    info: colors.info,
    grey: colors.grey,
    background: {
      default: '#f8f9fa',
      paper: '#ffffff'
    },
    text: {
      primary: '#212529',
      secondary: '#6c757d',
      disabled: '#adb5bd'
    }
  },
  typography: {
    fontFamily: [
      '-apple-system',
      'BlinkMacSystemFont',
      '"Segoe UI"',
      'Roboto',
      '"Helvetica Neue"',
      'Arial',
      'sans-serif',
      '"Apple Color Emoji"',
      '"Segoe UI Emoji"',
      '"Segoe UI Symbol"'
    ].join(','),
    h1: {
      fontSize: '2.5rem',
      fontWeight: 600,
      lineHeight: 1.2
    },
    h2: {
      fontSize: '2rem',
      fontWeight: 600,
      lineHeight: 1.3
    },
    h3: {
      fontSize: '1.75rem',
      fontWeight: 600,
      lineHeight: 1.4
    },
    h4: {
      fontSize: '1.5rem',
      fontWeight: 600,
      lineHeight: 1.4
    },
    h5: {
      fontSize: '1.25rem',
      fontWeight: 600,
      lineHeight: 1.5
    },
    h6: {
      fontSize: '1rem',
      fontWeight: 600,
      lineHeight: 1.5
    },
    body1: {
      fontSize: '1rem',
      lineHeight: 1.6
    },
    body2: {
      fontSize: '0.875rem',
      lineHeight: 1.5
    },
    button: {
      textTransform: 'none',
      fontWeight: 500
    }
  },
  shape: {
    borderRadius: 8
  },
  spacing: 8,
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 500,
          borderRadius: 8,
          padding: '8px 16px',
          '&:hover': {
            transform: 'translateY(-1px)',
            boxShadow: '0 4px 8px rgba(0, 0, 0, 0.12)'
          }
        },
        contained: {
          boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)',
          '&:hover': {
            boxShadow: '0 4px 8px rgba(0, 0, 0, 0.15)'
          }
        }
      }
    },
    MuiCard: {
      styleOverrides: {
        root: {
          boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
          borderRadius: 12,
          '&:hover': {
            boxShadow: '0 4px 16px rgba(0, 0, 0, 0.15)'
          }
        }
      }
    },
    MuiTab: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 500,
          fontSize: '0.875rem',
          minWidth: 120
        }
      }
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableCell-head': {
            backgroundColor: colors.grey[50],
            fontWeight: 600,
            color: colors.grey[800]
          }
        }
      }
    },
    MuiChip: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          fontWeight: 500
        }
      }
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)',
          borderBottom: `1px solid ${colors.grey[200]}`
        }
      }
    }
  },
  status: {
    danger: colors.error.main,
    warning: colors.warning.main,
    success: colors.success.main,
    info: colors.info.main
  }
});

// Dark theme variant
export const darkTheme = createTheme({
  ...theme,
  palette: {
    mode: 'dark',
    primary: colors.primary,
    secondary: colors.secondary,
    success: colors.success,
    warning: colors.warning,
    error: colors.error,
    info: colors.info,
    background: {
      default: '#121212',
      paper: '#1e1e1e'
    },
    text: {
      primary: '#ffffff',
      secondary: '#aaaaaa',
      disabled: '#666666'
    }
  }
});

export default theme;