"use client";
import React, { useState, useEffect } from "react";
import { AlertCircle } from "lucide-react";

const Toast = ({ message, isVisible, onClose }) => {
  useEffect(() => {
    if (isVisible) {
      const timer = setTimeout(() => {
        onClose();
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [isVisible, onClose]);

  if (!isVisible) return null;

  return (
    <div className="fixed top-4 left-1/2 transform -translate-x-1/2 z-50">
      <div className="bg-red-500 text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-2">
        <AlertCircle size={24} />
        <span>{message}</span>
      </div>
    </div>
  );
};

export default Toast;
