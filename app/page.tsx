"use client";
import React, { useState, useEffect } from "react";
import { Loader2, BusIcon, Sun, Moon, Github } from "lucide-react";
import QRCodeGenerator from "./components/QRCodeGenerator";
import Toast from "./components/Toast";

const BusReservationPage = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [reservationResult, setReservationResult] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [toastVisible, setToastVisible] = useState(false);
  const [toastMessage, setToastMessage] = useState("");
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem("authToken");
    if (token) {
      handleAuth(token);
    }
  }, []);

  const handleAuth = async (token) => {
    setIsLoading(true);
    setErrorMessage("");
    try {
      const response = await fetch(`/api/auth?password=${token}`);
      const data = await response.json();
      if (data.success) {
        setIsAuthenticated(true);
        handleReservation();
      } else {
        setErrorMessage(data.message);
        localStorage.removeItem("authToken");
      }
    } catch (error) {
      setErrorMessage("认证过程中发生错误");
      localStorage.removeItem("authToken");
    }
    setIsLoading(false);
  };

  const handleReservation = async () => {
    setIsLoading(true);
    setErrorMessage("");
    try {
      const response = await fetch("/api/reserve");
      const data = await response.json();
      if (data.success) {
        setReservationResult(data);
      } else {
        setErrorMessage(data.message);
      }
    } catch (error) {
      setErrorMessage("预约过程中发生错误");
    }
    setIsLoading(false);
  };

  const handleReverseBus = async () => {
    setToastMessage("正在尝试预约反向班车...");
    setToastVisible(true);
    await handleReservation();
  };

  const toggleDarkMode = () => {
    setIsDarkMode(!isDarkMode);
    document.documentElement.classList.toggle("dark");
  };

  const handleLogin = async (event) => {
    event.preventDefault();
    const password = event.target.password.value;
    localStorage.setItem("authToken", password);
    handleAuth(password);
  };

  return (
    <main
      className={`min-h-screen flex flex-col items-center sm:justify-center p-4 bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-zinc-800 dark:to-slate-900 ${
        isDarkMode ? "dark" : ""
      }`}
    >
      <div className="rounded-xl shadow-lg p-6 max-w-md w-full bg-white dark:bg-gray-800">
        {isAuthenticated ? (
          <div>
            <div className="mb-4 pb-3 border-b border-indigo-100 dark:border-gray-700 flex justify-between items-center">
              <p className="text-lg text-indigo-600 dark:text-indigo-300">
                欢迎使用班车预约系统
              </p>
              <div className="flex items-center space-x-2">
                <a
                  href="https://github.com/your-repo"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="p-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 dark:focus:ring-gray-500"
                >
                  <Github size={20} />
                </a>
                <button
                  onClick={toggleDarkMode}
                  className="p-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 dark:focus:ring-gray-500"
                >
                  {isDarkMode ? <Sun size={20} /> : <Moon size={20} />}
                </button>
              </div>
            </div>
            {isLoading ? (
              <div className="flex flex-col items-center space-y-3">
                <Loader2 className="h-12 w-12 animate-spin text-indigo-500 dark:text-indigo-300" />
                <p className="text-xl text-indigo-600 dark:text-indigo-300">
                  正在加载班车信息...
                </p>
              </div>
            ) : reservationResult ? (
              <div className="space-y-6">
                <div className="rounded-lg p-4 space-y-3 bg-indigo-50 dark:bg-gray-700">
                  <div className="flex justify-between items-center pb-2 border-b border-indigo-200 dark:border-gray-600">
                    <h3 className="text-xl font-semibold text-indigo-800 dark:text-indigo-200">
                      预约成功
                    </h3>
                    <span className="px-3 py-1 rounded-full text-sm font-medium bg-emerald-100 text-emerald-800 dark:bg-emerald-800 dark:text-emerald-200">
                      {reservationResult.qrcode_type}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-lg text-indigo-600 dark:text-indigo-300">
                      班车路线
                    </span>
                    <span className="text-lg font-medium text-indigo-900 dark:text-indigo-100">
                      {reservationResult.route_name}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-lg text-indigo-600 dark:text-indigo-300">
                      发车时间
                    </span>
                    <span className="text-lg font-medium text-indigo-900 dark:text-indigo-100">
                      {reservationResult.start_time}
                    </span>
                  </div>
                </div>
                <div className="flex justify-center">
                  <QRCodeGenerator value={reservationResult.qrcode} />
                </div>
                <button
                  onClick={handleReverseBus}
                  className="w-full px-6 py-3 text-white text-lg font-semibold rounded-lg transition duration-300 ease-in-out focus:outline-none focus:ring-2 focus:ring-opacity-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-700 focus:ring-indigo-500 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-500"
                  disabled={isLoading}
                >
                  <BusIcon size={24} />
                  <span>乘坐反向班车</span>
                </button>
              </div>
            ) : (
              <button
                onClick={handleReservation}
                className="w-full px-6 py-3 mt-4 text-white text-lg font-semibold rounded-lg transition duration-300 ease-in-out focus:outline-none focus:ring-2 focus:ring-opacity-50 disabled:opacity-50 disabled:cursor-not-allowed bg-indigo-600 hover:bg-indigo-700 focus:ring-indigo-500 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-500"
                disabled={isLoading}
              >
                预约班车
              </button>
            )}
          </div>
        ) : (
          <form onSubmit={handleLogin} className="space-y-4">
            <h1 className="text-2xl font-bold text-center text-indigo-800 dark:text-indigo-200">
              班车预约系统
            </h1>
            <input
              type="password"
              name="password"
              placeholder="请输入密码"
              className="w-full px-4 py-2 rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
              required
            />
            <button
              type="submit"
              disabled={isLoading}
              className="w-full px-4 py-2 text-white bg-indigo-600 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-opacity-50 dark:bg-blue-600 dark:hover:bg-blue-700"
            >
              {isLoading ? "登录中..." : "登录"}
            </button>
            {errorMessage && (
              <p className="text-red-500 text-center">{errorMessage}</p>
            )}
          </form>
        )}
      </div>
      <Toast
        message={toastMessage}
        isVisible={toastVisible}
        onClose={() => setToastVisible(false)}
      />
    </main>
  );
};

export default BusReservationPage;
