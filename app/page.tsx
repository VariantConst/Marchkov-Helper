"use client";
import React, { useState, useEffect } from "react";
import { Loader2, BusIcon, Sun, Moon, Github } from "lucide-react";
import Toast from "./components/Toast";
import SplashScreen from "./components/SplashScreen";
import PageLogin from "./components/PageLogin";
import ResultCard from "./components/ResultCard";
import { AuthError, ReservationResult } from "./types";

const BusReservationPage: React.FC = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [reservationResult, setReservationResult] =
    useState<ReservationResult | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [isFirstLoad, setIsFirstLoad] = useState(true);
  const [isReverseLoading, setIsReverseLoading] = useState(false);
  const [showSplash, setShowSplash] = useState(false);
  const [toastMessage, setToastMessage] = useState("");
  const [toastVisible, setToastVisible] = useState(false);
  const [toastSuccess, setToastSuccess] = useState(true);
  const [username, setUsername] = useState("");

  const handleError = (error: unknown, defaultMessage: string) => {
    if (error instanceof Error) {
      return error.message;
    }
    return defaultMessage;
  };

  useEffect(() => {
    const initializeApp = async () => {
      const token = localStorage.getItem("authToken");
      if (token) {
        try {
          await handleAuth(token);
        } catch (error) {
          setErrorMessage(handleError(error, "初始化过程中发生未知错误"));
          setIsLoading(false);
        }
      } else {
        setIsLoading(false);
      }
    };

    initializeApp();
  }, []);

  const handleAuth = async (token: string) => {
    setErrorMessage("");
    try {
      const authResponse = await fetch(`/api/auth?token=${token}`);
      const authData = await authResponse.json();
      if (authData.success) {
        setIsAuthenticated(true);
        localStorage.setItem("authToken", token);
        setShowSplash(true);
        const loginResponse = await fetch("/api/login");
        const loginData = await loginResponse.json();
        if (loginData.success) {
          setUsername(loginData.username);
          await handleReservation();
        } else {
          throw new Error(loginData.message);
        }
      } else {
        throw new Error(authData.message);
      }
    } catch (error) {
      localStorage.removeItem("authToken");
      throw error;
    } finally {
      setIsLoading(false);
      setShowSplash(false);
    }
  };

  const handleReservation = async (isReverse = false) => {
    if (!isReverse) {
      setIsLoading(true);
    }
    setErrorMessage("");
    try {
      const currentDirection = reservationResult?.is_to_yanyuan;
      const url = new URL("/api/reserve", window.location.origin);
      url.searchParams.append("is_first_load", String(isFirstLoad));

      if (currentDirection !== undefined) {
        url.searchParams.append(
          "is_to_yanyuan",
          String(isReverse ? !currentDirection : currentDirection)
        );
      }

      const old_app_id = reservationResult?.app_id;
      const old_app_appointment_id = reservationResult?.app_appointment_id;

      const response = await fetch(url);
      const data = await response.json();
      if (data.success) {
        setReservationResult(data);
        setIsFirstLoad(false);
        if (isReverse && reservationResult?.qrcode_type === "乘车码") {
          if (!old_app_id || !old_app_appointment_id) {
            throw new Error("无法取消预约");
          }
          cancel_reservation(old_app_id, old_app_appointment_id);
        }

        setToastMessage(isReverse ? "反向预约成功" : "班车预约成功");
        setToastSuccess(true);
      } else {
        if (isReverse) {
          setToastMessage("反向无车可坐");
          setToastSuccess(false);
        } else {
          throw new Error(data.message);
        }
      }
    } catch (error) {
      const errorMessage = handleError(error, "预约过程中发生错误");
      setErrorMessage(errorMessage);
      setToastMessage(errorMessage);
      setToastSuccess(false);
    } finally {
      if (!isReverse) {
        setIsLoading(false);
      } else {
        setToastVisible(true);
      }
    }
  };

  const handleReverseBus = async () => {
    setIsReverseLoading(true);
    await handleReservation(true);
    setIsReverseLoading(false);
  };

  const toggleDarkMode = () => {
    setIsDarkMode(!isDarkMode);
    document.documentElement.classList.toggle("dark");
  };

  const cancel_reservation = async (
    app_id: string | null,
    app_appointment_id: string | null
  ) => {
    try {
      const response = await fetch(
        `/api/cancel?app_id=${app_id ?? ""}&app_appointment_id=${
          app_appointment_id ?? ""
        }`
      );
      const data = await response.json();
      if (!data.success) {
        throw new Error(data.message);
      }
    } catch (error) {
      const errorMessage = handleError(error, "取消预约过程中发生错误");
      setErrorMessage(errorMessage);
      setToastMessage(errorMessage);
      setToastSuccess(false);
      setToastVisible(true);
    }
  };

  const handleLogin = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const password = (
      event.currentTarget.elements.namedItem("password") as HTMLInputElement
    ).value;
    try {
      await handleAuth(password);
    } catch (error) {
      setErrorMessage((error as AuthError).message || "认证失败");
    }
  };

  const renderContent = () => {
    if (isLoading || showSplash) {
      return <SplashScreen />;
    }

    if (errorMessage) {
      const emoji = errorMessage.includes("环境变量") ? "😇" : "😅";
      return (
        <div className="rounded-lg p-4 space-y-3 text-center">
          <p className="text-8xl">{emoji}</p>
          <p className="text-red-600 dark:text-red-300">{errorMessage}</p>
        </div>
      );
    }

    if (!isAuthenticated) {
      return <PageLogin handleLogin={handleLogin} />;
    }

    if (reservationResult) {
      return (
        <ResultCard
          reservationResult={reservationResult}
          handleReverseBus={handleReverseBus}
          isReverseLoading={isReverseLoading}
        />
      );
    }

    return null;
  };

  return (
    <main
      className={`min-h-screen flex flex-col items-center sm:justify-center p-4 bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-zinc-800 dark:to-slate-900 ${
        isDarkMode ? "dark" : ""
      }`}
    >
      <div className="rounded-xl shadow-lg p-6 max-w-md w-full bg-white dark:bg-gray-800">
        {isAuthenticated && (
          <div className="mb-4 pb-3 border-b border-indigo-100 dark:border-gray-700 flex justify-between items-center">
            <p className="text-lg text-indigo-600 dark:text-indigo-300">
              欢迎，<span className="font-semibold">{username}</span>
            </p>
            <div className="flex items-center space-x-2">
              <a
                href="https://github.com/VariantConst/3-2-1-Marchkov/"
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
        )}
        {renderContent()}
      </div>
      <Toast
        message={toastMessage}
        isVisible={toastVisible}
        onClose={() => setToastVisible(false)}
        isSuccess={toastSuccess}
      />
    </main>
  );
};

export default BusReservationPage;
