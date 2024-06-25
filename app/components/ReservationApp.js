// app/components/ReservationApp.js
"use client";

import { useState, useEffect, useRef } from "react";
import LoginForm from "./LoginForm";
import ReservationInfo from "./ReservationInfo";
import { loginAction, logoutAction, refreshReservationData } from "../actions";

export default function ReservationApp({
  initialUser,
  initialReservationData,
}) {
  const [isClient, setIsClient] = useState(false);
  const [user, setUser] = useState(null);
  const [reservationData, setReservationData] = useState(null);
  const initialDataFetchedRef = useRef(false);

  useEffect(() => {
    setIsClient(true);
    setUser(initialUser);
    setReservationData(initialReservationData);
  }, [initialUser, initialReservationData]);

  useEffect(() => {
    if (!isClient || !user || initialDataFetchedRef.current) return;

    const fetchInitialData = async () => {
      if (reservationData && reservationData.success) {
        // 如果已经有有效的预约数据，不再重新获取
        initialDataFetchedRef.current = true;
        return;
      }

      const result = await refreshReservationData();
      setReservationData(result);
      initialDataFetchedRef.current = true;
    };

    fetchInitialData();
  }, [isClient, user, reservationData]);

  const handleLogin = async (formData) => {
    const result = await loginAction(formData);
    setUser(result.user);
    setReservationData(result.reservationData);
    initialDataFetchedRef.current = true; // 登录时已获取数据，标记为已完成初始获取
  };

  const handleLogout = async () => {
    await logoutAction();
    setUser(null);
    setReservationData({ success: false, message: "", reservations: [] });
    initialDataFetchedRef.current = false; // 重置初始数据获取标志
  };

  const handleRefresh = async () => {
    if (user) {
      const result = await refreshReservationData();
      setReservationData(result);
    }
  };

  if (!isClient) {
    return null; // 或者返回一个加载指示器
  }

  return (
    <>
      {!user ? (
        <LoginForm onSubmit={handleLogin} />
      ) : (
        <ReservationInfo
          user={user}
          reservationData={reservationData}
          onLogout={handleLogout}
          onRefresh={handleRefresh}
        />
      )}
    </>
  );
}
