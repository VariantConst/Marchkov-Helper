import QRCode from "qrcode";
import React from "react";

const QRCodeGenerator: React.FC<{
  value: string;
  size?: number;
  version?: number;
}> = ({ value, size = 256, version = 9 }) => {
  const [svgString, setSvgString] = React.useState<string>("");

  React.useEffect(() => {
    QRCode.toString(
      value,
      {
        type: "svg",
        version: version,
        errorCorrectionLevel: "L",
        margin: 4,
        width: size,
      },
      (err, string) => {
        if (err) {
          console.error("Error generating QR code:", err);
        } else {
          setSvgString(string);
        }
      }
    );
  }, [value, size, version]);

  return (
    <div
      className="rounded-lg shadow-lg dark:shadow-slate-300/30"
      dangerouslySetInnerHTML={{ __html: svgString }}
      style={{ width: size, height: size }}
    />
  );
};

export default QRCodeGenerator;
