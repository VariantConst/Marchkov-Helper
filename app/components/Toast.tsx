import React, { useState, useEffect } from "react";
import { AlertCircle, CheckCircle } from "lucide-react";

type ToastProps = {
  message: string;
  isVisible: boolean;
  onClose: () => void;
  isSuccess?: boolean;
};

const Toast = ({
  message,
  isVisible,
  onClose,
  isSuccess = true,
}: ToastProps) => {
  const [isRendered, setIsRendered] = useState(false);

  useEffect(() => {
    if (isVisible) {
      setIsRendered(true);
      const timer = setTimeout(() => {
        setIsRendered(false);
        setTimeout(onClose, 300); // 等待退出动画完成后关闭
      }, 1000);
      return () => clearTimeout(timer);
    }
  }, [isVisible, onClose]);

  if (!isVisible && !isRendered) return null;

  const bgColor = isSuccess ? "bg-emerald-500" : "bg-red-500";
  const Icon = isSuccess ? CheckCircle : AlertCircle;

  return (
    <div
      className={`fixed top-0 left-0 right-0 flex justify-center items-start pt-7 z-50 transition-all duration-300 ease-in-out ${
        isRendered ? "translate-y-0 opacity-100" : "-translate-y-full opacity-0"
      }`}
    >
      <div
        className={`${bgColor} text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-3 transition-all duration-300 ease-in-out transform hover:scale-105`}
      >
        <Icon size={24} />
        <span className="font-medium">{message}</span>
      </div>
    </div>
  );
};

export default Toast;
