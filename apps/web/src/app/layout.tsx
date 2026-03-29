import type { Metadata } from "next";
import { Plus_Jakarta_Sans, Geist_Mono } from "next/font/google";
import { ThemeScript } from "./theme-script";
import { ThemeProvider } from "./theme-provider";
import "./globals.css";

const plusJakarta = Plus_Jakarta_Sans({
  variable: "--font-sans",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700", "800"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "SimCast — iOS Simulator Streaming",
  description: "Stream iOS Simulators live from your Mac to any browser, with real-time touch interaction over WebRTC.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${plusJakarta.variable} ${geistMono.variable} antialiased`}>
        <ThemeScript />
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
