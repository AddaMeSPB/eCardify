import type { Metadata, Viewport } from "next";
import { DM_Sans, Instrument_Serif } from "next/font/google";
import "./globals.css";

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm-sans",
  display: "swap",
});

const instrumentSerif = Instrument_Serif({
  weight: "400",
  subsets: ["latin"],
  variable: "--font-instrument-serif",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://ecardify.addame.com"),
  title: "eCardify - Digital Business Card for iPhone",
  description:
    "Create professional digital business cards, save to Apple Wallet, and share via QR code or AirDrop. No app needed on the other end.",
  keywords: [
    "digital business card",
    "virtual business card",
    "QR code",
    "Apple Wallet",
    "networking",
    "vCard",
    "contact sharing",
  ],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "eCardify - Digital Business Card for iPhone",
    description:
      "Create professional digital business cards in under 2 minutes.",
    type: "website",
    siteName: "eCardify",
    url: "https://ecardify.addame.com",
  },
  twitter: {
    card: "summary_large_image",
    title: "eCardify - Digital Business Card for iPhone",
    description:
      "Create professional digital business cards in under 2 minutes.",
  },
  other: {
    "apple-itunes-app": "app-id=1619504857",
    "color-scheme": "light dark",
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#1d5af1" },
    { media: "(prefers-color-scheme: dark)", color: "#0a0e17" },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body
        className={`${dmSans.variable} ${instrumentSerif.variable} font-sans antialiased bg-surface text-gray-900 dark:bg-surface-dark dark:text-gray-100`}
      >
        {children}
      </body>
    </html>
  );
}
