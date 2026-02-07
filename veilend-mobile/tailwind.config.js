/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./App.{js,jsx,ts,tsx}", "./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#A855F7",
        secondary: "#00D1FF",
        background: "#0A0A0A",
        card: "#1A1A1A",
        text: "#FFFFFF",
        textSecondary: "#A1A1A1",
      },
    },
  },
  plugins: [],
}
