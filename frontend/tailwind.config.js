/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      // PowerShell GUI 互換の色設定
      colors: {
        microsoft: {
          50: '#f3f9ff',
          100: '#e6f3ff',
          200: '#bde4ff',
          300: '#85d1ff',
          400: '#47baff',
          500: '#0078d4',  // Microsoft Blue
          600: '#106ebe',
          700: '#005a9e',
          800: '#004578',
          900: '#003152',
        },
        powershell: {
          50: '#f0f8ff',
          100: '#e0f2ff',
          200: '#bae6fd',
          300: '#7dd3fc',
          400: '#38bdf8',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          800: '#075985',
          900: '#0c4a6e',
        }
      },
      
      // フォントサイズ（アクセシビリティ対応）
      fontSize: {
        'xs': ['0.75rem', { lineHeight: '1rem' }],
        'sm': ['0.875rem', { lineHeight: '1.25rem' }],
        'base': ['1rem', { lineHeight: '1.5rem' }],
        'lg': ['1.125rem', { lineHeight: '1.75rem' }],
        'xl': ['1.25rem', { lineHeight: '1.75rem' }],
        '2xl': ['1.5rem', { lineHeight: '2rem' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
        '5xl': ['3rem', { lineHeight: '1' }],
        '6xl': ['3.75rem', { lineHeight: '1' }],
        '7xl': ['4.5rem', { lineHeight: '1' }],
        '8xl': ['6rem', { lineHeight: '1' }],
        '9xl': ['8rem', { lineHeight: '1' }],
      },
      
      // スペーシング（PowerShell GUI 互換）
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '190': '47.5rem', // PowerShell button width
        '50': '12.5rem',  // PowerShell button height
      },
      
      // ボーダー半径
      borderRadius: {
        'sm': '0.125rem',
        'md': '0.25rem',
        'lg': '0.5rem',
        'xl': '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
      
      // アニメーション
      animation: {
        'fade-in': 'fadeIn 0.3s ease-in-out',
        'slide-in': 'slideIn 0.3s ease-in-out',
        'bounce-subtle': 'bounceSubtle 0.5s ease-in-out',
        'pulse-subtle': 'pulseSubtle 2s ease-in-out infinite',
      },
      
      // キーフレーム
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { transform: 'translateX(-10px)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' },
        },
        bounceSubtle: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-5px)' },
        },
        pulseSubtle: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.8' },
        },
      },
      
      // ブレークポイント（レスポンシブ）
      screens: {
        'xs': '320px',
        'sm': '640px',
        'md': '768px',
        'lg': '1024px',
        'xl': '1280px',
        '2xl': '1536px',
        '3xl': '1920px',
      },
      
      // グリッドテンプレート
      gridTemplateColumns: {
        'feature-2': 'repeat(2, 190px)',
        'feature-3': 'repeat(3, 190px)',
        'feature-4': 'repeat(4, 190px)',
        'feature-auto': 'repeat(auto-fit, minmax(190px, 1fr))',
      },
      
      // 影設定
      boxShadow: {
        'feature-card': '0 2px 8px rgba(0, 0, 0, 0.1)',
        'feature-card-hover': '0 4px 16px rgba(0, 0, 0, 0.15)',
        'modal': '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
      },
      
      // トランジション
      transitionProperty: {
        'height': 'height',
        'spacing': 'margin, padding',
        'colors': 'color, background-color, border-color',
      },
      
      // Z-index
      zIndex: {
        '60': '60',
        '70': '70',
        '80': '80',
        '90': '90',
        '100': '100',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    
    // カスタムプラグイン
    function({ addUtilities, addComponents, theme }) {
      // PowerShell GUI 互換ボタンスタイル
      const featureButtons = {
        '.feature-button': {
          width: '190px',
          height: '50px',
          backgroundColor: theme('colors.microsoft.500'),
          color: theme('colors.white'),
          border: `1px solid ${theme('colors.microsoft.700')}`,
          borderRadius: theme('borderRadius.md'),
          fontWeight: theme('fontWeight.bold'),
          fontSize: theme('fontSize.sm'),
          cursor: 'pointer',
          transition: 'all 0.2s ease-in-out',
          '&:hover': {
            backgroundColor: theme('colors.microsoft.600'),
            transform: 'translateY(-1px)',
          },
          '&:active': {
            backgroundColor: theme('colors.microsoft.700'),
            transform: 'translateY(0)',
          },
          '&:focus': {
            outline: 'none',
            boxShadow: `0 0 0 2px ${theme('colors.microsoft.500')}`,
          },
          '&:disabled': {
            backgroundColor: theme('colors.gray.400'),
            borderColor: theme('colors.gray.500'),
            cursor: 'not-allowed',
            transform: 'none',
          },
        },
      };
      
      // アクセシビリティユーティリティ
      const accessibilityUtils = {
        '.sr-only': {
          position: 'absolute',
          width: '1px',
          height: '1px',
          padding: '0',
          margin: '-1px',
          overflow: 'hidden',
          clip: 'rect(0, 0, 0, 0)',
          whiteSpace: 'nowrap',
          border: '0',
        },
        '.focus-visible': {
          '&:focus-visible': {
            outline: `2px solid ${theme('colors.microsoft.500')}`,
            outlineOffset: '2px',
          },
        },
        '.reduce-motion': {
          '@media (prefers-reduced-motion: reduce)': {
            '*, *::before, *::after': {
              animationDuration: '0.01ms !important',
              animationIterationCount: '1 !important',
              transitionDuration: '0.01ms !important',
            },
          },
        },
      };
      
      // 高コントラストモード
      const highContrastUtils = {
        '.high-contrast': {
          filter: 'contrast(150%)',
          '& .feature-button': {
            borderWidth: '2px',
            backgroundColor: theme('colors.black'),
            color: theme('colors.white'),
            '&:hover': {
              backgroundColor: theme('colors.gray.800'),
            },
          },
        },
      };
      
      // レスポンシブグリッド
      const responsiveGrids = {
        '.feature-grid': {
          display: 'grid',
          gap: theme('spacing.4'),
          justifyContent: 'center',
          '@media (min-width: 320px)': {
            gridTemplateColumns: 'repeat(1, 190px)',
          },
          '@media (min-width: 640px)': {
            gridTemplateColumns: 'repeat(2, 190px)',
          },
          '@media (min-width: 1024px)': {
            gridTemplateColumns: 'repeat(3, 190px)',
          },
          '@media (min-width: 1280px)': {
            gridTemplateColumns: 'repeat(4, 190px)',
          },
        },
        '.feature-grid-2x2': {
          display: 'grid',
          gap: theme('spacing.4'),
          justifyContent: 'center',
          gridTemplateColumns: 'repeat(2, 190px)',
          '@media (max-width: 640px)': {
            gridTemplateColumns: 'repeat(1, 190px)',
          },
        },
        '.feature-grid-3x2': {
          display: 'grid',
          gap: theme('spacing.4'),
          justifyContent: 'center',
          gridTemplateColumns: 'repeat(3, 190px)',
          '@media (max-width: 1024px)': {
            gridTemplateColumns: 'repeat(2, 190px)',
          },
          '@media (max-width: 640px)': {
            gridTemplateColumns: 'repeat(1, 190px)',
          },
        },
      };
      
      addComponents({
        ...featureButtons,
        ...responsiveGrids,
      });
      
      addUtilities({
        ...accessibilityUtils,
        ...highContrastUtils,
      });
    }
  ],
  
  // ダークモード設定
  darkMode: 'class',
  
  // 重要度の順序
  important: false,
  
  // プリフライト無効化（必要に応じて）
  corePlugins: {
    preflight: true,
  },
};