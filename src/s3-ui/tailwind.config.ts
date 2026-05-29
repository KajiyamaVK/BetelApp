import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: ['class'],
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#FFBD00',
        background: '#F5F5F5',
        surface: '#FFFFFF',
        'text-main': '#333333',
        'delete-bg': '#EF9A9A',
        'delete-text': '#C62828',
        success: '#81C784',
        warning: '#E57373',
      },
      fontFamily: {
        sans: ['Poppins', 'sans-serif'],
      },
    },
  },
  plugins: [],
}

export default config
