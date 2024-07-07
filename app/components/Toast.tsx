"use client";
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
  useEffect(() => {
    if (isVisible) {
      const timer = setTimeout(() => {
        onClose();
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [isVisible, onClose]);

  if (!isVisible) return null;

  const bgColor = isSuccess ? "bg-emerald-500" : "bg-red-500";
  const Icon = isSuccess ? CheckCircle : AlertCircle;

  return (
    <div className="fixed top-4 left-1/2 transform -translate-x-1/2 z-50">
      <div
        className={`${bgColor} text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-2`}
      >
        <Icon size={24} />
        <span>{message}</span>
      </div>
    </div>
  );
};

export default Toast;
