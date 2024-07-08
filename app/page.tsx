"use client";
import React, { useState, useEffect } from "react";
import Toast from "./components/Toast";
import { AuthError, ReservationResult } from "./types";
import BusReservationContent from "./components/BusReservationContent";

const BusReservationPage: React.FC = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [reservationResult, setReservationResult] =
    useState<ReservationResult | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isDarkMode, setIsDarkMode] = useState(() => {
    if (typeof window !== "undefined") {
      return window.matchMedia("(prefers-color-scheme: dark)").matches;
    }
    return false;
  });
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
    const darkModeMediaQuery = window.matchMedia(
      "(prefers-color-scheme: dark)"
    );
    const handleChange = (e: MediaQueryListEvent) => {
      setIsDarkMode(e.matches);
      document.documentElement.classList.toggle("dark", e.matches);
    };

    darkModeMediaQuery.addEventListener("change", handleChange);
    document.documentElement.classList.toggle("dark", isDarkMode);

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

    return () => darkModeMediaQuery.removeEventListener("change", handleChange);
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

  return (
    <main
      className={`min-h-screen flex flex-col items-center sm:justify-center p-4 bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-zinc-800 dark:to-slate-900 ${
        isDarkMode ? "dark" : ""
      }`}
    >
      <BusReservationContent
        isLoading={isLoading}
        showSplash={showSplash}
        errorMessage={errorMessage}
        isAuthenticated={isAuthenticated}
        username={username}
        reservationResult={reservationResult}
        isDarkMode={isDarkMode}
        isReverseLoading={isReverseLoading}
        handleLogin={handleLogin}
        handleReverseBus={handleReverseBus}
        toggleDarkMode={toggleDarkMode}
      />
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
