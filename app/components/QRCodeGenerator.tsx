import QRCode from "qrcode";
import React, { useState, useEffect, useCallback } from "react";

interface QRCodeGeneratorProps {
  value: string;
  size?: number;
  initialVersion?: number;
  onError?: () => Promise<string>;
}

const QRCodeGenerator: React.FC<QRCodeGeneratorProps> = ({
  value,
  size = 256,
  initialVersion = 9,
  onError,
}) => {
  const [svgString, setSvgString] = useState<string>("");
  const [retryCount, setRetryCount] = useState(0);
  const [currentVersion, setCurrentVersion] = useState(initialVersion);

  const generateQRCode = useCallback(
    async (qrValue: string, version: number) => {
      try {
        const string = await QRCode.toString(qrValue, {
          type: "svg",
          version: version,
          errorCorrectionLevel: "L",
          margin: 4,
          width: size,
        });
        setSvgString(string);
        setRetryCount(0);
      } catch (err) {
        console.error("Error generating QR code:", err);
        if (
          err instanceof Error &&
          err.message.includes("Minimum version required")
        ) {
          // 提取错误信息中的最小版本号
          const minVersionMatch = err.message.match(
            /Minimum version required to store current data is: (\d+)/
          );
          if (minVersionMatch) {
            const minVersion = parseInt(minVersionMatch[1], 10);
            setCurrentVersion(minVersion);
            generateQRCode(qrValue, minVersion);
          } else {
            setCurrentVersion((prev) => prev + 1);
            generateQRCode(qrValue, currentVersion + 1);
          }
        } else if (onError && retryCount < 5) {
          const newValue = await onError();
          setRetryCount((prev) => prev + 1);
          generateQRCode(newValue, currentVersion);
        }
      }
    },
    [size, onError, retryCount, currentVersion]
  );

  useEffect(() => {
    generateQRCode(value, currentVersion);
  }, [value, currentVersion, generateQRCode]);

  return (
    <div
      className="rounded-lg shadow-lg dark:shadow-slate-300/30"
      dangerouslySetInnerHTML={{ __html: svgString }}
      style={{ width: size, height: size }}
    />
  );
};

export default QRCodeGenerator;
