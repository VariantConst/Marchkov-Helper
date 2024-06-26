// components/ReservationApp.js
"use client";

import React, { useState, useEffect, useCallback } from "react";
import { useTheme } from "next-themes";
import LoginForm from "./LoginForm";
import ReservationInfo from "./ReservationInfo";
import LoadingOverlay from "./LoadingOverlay";
import Header from "../Header";
import { loginAction, logoutAction, refreshReservationData } from "../actions";

export default function ReservationApp({
  initialUser,
  initialReservationData,
}) {
  const [isClient, setIsClient] = useState(false);
  const [user, setUser] = useState(initialUser);
  const [reservationData, setReservationData] = useState(
    initialReservationData
  );
  const [isLoading, setIsLoading] = useState(false);
  const [needsRefresh, setNeedsRefresh] = useState(false);
  const { theme, setTheme } = useTheme();

  const handleRefresh = useCallback(async () => {
    if (user && !isLoading) {
      setIsLoading(true);
      try {
        const result = await refreshReservationData();
        setReservationData(result);
        setNeedsRefresh(false);
      } catch (error) {
        console.error("Refresh failed:", error);
        setReservationData({
          success: false,
          message: "刷新失败，请重试",
          reservations: [],
        });
      } finally {
        setIsLoading(false);
      }
    }
  }, [user, isLoading]);

  useEffect(() => {
    setIsClient(true);
    if (
      initialUser &&
      (!initialReservationData || !initialReservationData.success)
    ) {
      setNeedsRefresh(true);
    }
  }, []);

  useEffect(() => {
    if (isClient && needsRefresh) {
      handleRefresh();
    }
  }, [isClient, needsRefresh, handleRefresh]);

  const handleLogin = async (formData) => {
    setIsLoading(true);
    try {
      const result = await loginAction(formData);
      setUser(result.user);
      setReservationData(result.reservationData);
    } catch (error) {
      console.error("Login failed:", error);
      setReservationData({
        success: false,
        message: "登录失败，请重试",
        reservations: [],
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleLogout = async () => {
    setIsLoading(true);
    try {
      await logoutAction();
      setUser(null);
      setReservationData({ success: false, message: "", reservations: [] });
    } catch (error) {
      console.error("Logout failed:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const toggleTheme = () => {
    setTheme(theme === "dark" ? "light" : "dark");
  };

  if (!isClient) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-100 dark:bg-gray-900 transition-colors duration-200">
      <Header
        user={user}
        onLogout={handleLogout}
        onThemeToggle={toggleTheme}
        theme={theme}
      />
      <main className="max-w-7xl mx-auto py-2 sm:px-6 lg:px-8">
        <div className="p-2 sm:px-0">
          <LoadingOverlay isLoading={isLoading} />
          {!user ? (
            <LoginForm onSubmit={handleLogin} />
          ) : (
            <ReservationInfo user={user} reservationData={reservationData} />
          )}
        </div>
      </main>
    </div>
  );
}
