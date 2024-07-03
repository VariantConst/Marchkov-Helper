import QRCode from "qrcode";
import React, { useState, useEffect } from "react";

interface QRCodeGeneratorProps {
  value: string;
}

const QRCodeGenerator: React.FC<QRCodeGeneratorProps> = ({ value }) => {
  const [svgString, setSvgString] = useState<string>("");
  const size = 256;

  useEffect(() => {
    const generateQRCode = async () => {
      try {
        const string = await QRCode.toString(value, {
          type: "svg",
          errorCorrectionLevel: "M",
          margin: 4,
          width: size,
        });
        setSvgString(string);
      } catch (err) {
        console.error("Error generating QR code:", err);
      }
    };

    generateQRCode();
  }, [value, size]);

  return (
    <div
      className="rounded-lg shadow-lg dark:shadow-slate-300/30"
      dangerouslySetInnerHTML={{ __html: svgString }}
      style={{ width: size, height: size }}
    />
  );
};

export default QRCodeGenerator;
