import React, { useMemo } from "react";
import QRCode from "qrcode";

interface QRCodeGeneratorProps {
  value: string;
}

const QRCodeGenerator: React.FC<QRCodeGeneratorProps> = React.memo(
  ({ value }) => {
    const size = 256;

    const svgString = useMemo(() => {
      let svg = "";
      QRCode.toString(
        value,
        {
          type: "svg",
          errorCorrectionLevel: "M",
          margin: 4,
          version: 11,
          width: size,
        },
        (err, string) => {
          if (!err) svg = string;
        }
      );
      return svg;
    }, [value, size]);

    console.log(`渲染了具有 ${value} 字面值的二维码`);

    return (
      <div
        className="rounded-lg shadow-lg dark:shadow-slate-300/30"
        dangerouslySetInnerHTML={{ __html: svgString }}
        style={{ width: size, height: size }}
      />
    );
  }
);

QRCodeGenerator.displayName = "QRCodeGenerator";

export default QRCodeGenerator;
