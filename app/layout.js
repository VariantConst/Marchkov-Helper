import "./globals.css";

export const metadata = {
  title: "班车预约系统",
  description: "北京大学班车预约系统",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh">
      <body>{children}</body>
    </html>
  );
}
