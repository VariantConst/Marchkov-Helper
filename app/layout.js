import "./globals.css";

export const metadata = {
  title: "3-2-1-马池口！",
  description: "新燕园班车自动预约系统",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh">
      <body>{children}</body>
    </html>
  );
}
