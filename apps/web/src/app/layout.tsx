import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "NOXUND — Market intelligence engine for producers",
  description:
    "NOXUND Hotspot Artists Report. Market intelligence engine for producers.",
  robots: { index: false, follow: false },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
