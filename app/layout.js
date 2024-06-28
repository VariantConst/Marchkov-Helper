import "./globals.css";

export const metadata = {
  title: "3-2-1-马池口！",
  description: "新燕园班车自动预约系统",
  icons: {
    icon: "/favicon.png",
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh">
      <head>
        <link rel="icon" href="/favicon.png" />
      </head>
      <body>{children}</body>
    </html>
  );
}
