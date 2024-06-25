// app/page.js
"use client";

import { useState, useEffect, useRef } from "react";
import {
  loginAction,
  logoutAction,
  checkLoginStatus,
  refreshReservationData,
} from "./actions";

export default function Home() {
  const [user, setUser] = useState(null);
  const [reservationData, setReservationData] = useState({
    success: false,
    message: "",
    reservations: [],
  });
  const [loading, setLoading] = useState(true);
  const initRef = useRef(false);

  useEffect(() => {
    const initializeApp = async () => {
      if (initRef.current) return;
      initRef.current = true;

      const result = await checkLoginStatus();
      if (result.user) {
        setUser(result.user);
        setReservationData(result.reservationData);
      }
      setLoading(false);
    };
    initializeApp();
  }, []);

  const handleLogin = async (formData) => {
    const result = await loginAction(formData);
    setUser(result.user);
    setReservationData(result.reservationData);
  };

  const handleLogout = () => {
    logoutAction();
    setUser(null);
    setReservationData({ success: false, message: "", reservations: [] });
  };

  const handleRefresh = async () => {
    if (user) {
      const result = await refreshReservationData();
      setReservationData(result);
    }
  };

  if (loading) {
    return <div>加载中...</div>;
  }

  return (
    <div className="container mx-auto p-4">
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
    </div>
  );
}

function LoginForm({ onSubmit }) {
  const [currentTime, setCurrentTime] = useState("");

  useEffect(() => {
    // 获取当前北京时间
    const now = new Date(
      new Date().toLocaleString("en-US", { timeZone: "Asia/Shanghai" })
    );
    const hours = String(now.getHours()).padStart(2, "0");
    const minutes = String(now.getMinutes()).padStart(2, "0");
    setCurrentTime(`${hours}:${minutes}`);
  }, []);

  return (
    <form action={onSubmit}>
      <h1 className="text-2xl mb-4">用户登录</h1>
      <input
        type="text"
        name="username"
        placeholder="用户名"
        className="block border p-2 mb-4"
        required
      />
      <input
        type="password"
        name="password"
        placeholder="密码"
        className="block border p-2 mb-4"
        required
      />
      <input
        type="time"
        name="currentTime"
        placeholder="当前时间 (HH:MM)"
        className="block border p-2 mb-4"
        defaultValue={currentTime}
      />
      <input
        type="time"
        name="criticalTime"
        placeholder="临界时间 (HH:MM)"
        className="block border p-2 mb-4"
        required
      />
      <div className="mb-4">
        <p className="mb-2">在临界时刻之前去：</p>
        <label className="inline-flex items-center mr-4">
          <input
            type="radio"
            name="direction"
            value="toChangping"
            className="mr-2"
            required
          />
          去昌平
        </label>
        <label className="inline-flex items-center">
          <input
            type="radio"
            name="direction"
            value="toYanyuan"
            className="mr-2"
            required
          />
          去燕园
        </label>
      </div>
      <button type="submit" className="bg-blue-500 text-white p-2">
        登录
      </button>
    </form>
  );
}

function ReservationInfo({ user, reservationData, onLogout, onRefresh }) {
  return (
    <div>
      <h1 className="text-2xl mb-4">已登录为: {user.username}</h1>
      <p>临界时刻: {user.criticalTime}</p>
      <p>方向: {user.direction === "toChangping" ? "去昌平" : "去燕园"}</p>
      <button onClick={onLogout} className="bg-red-500 text-white p-2 mr-2">
        登出
      </button>
      <button onClick={onRefresh} className="bg-blue-500 text-white p-2 mt-2">
        刷新预约信息
      </button>
      <h2 className="text-xl mt-4">班车信息</h2>
      {reservationData.message && (
        <p
          className={`mt-2 ${
            reservationData.success ? "text-green-600" : "text-red-600"
          }`}
        >
          {reservationData.message}
        </p>
      )}
      {reservationData.success && reservationData.reservations.length > 0 ? (
        <ul className="mt-4">
          {reservationData.reservations.map((reservation, index) => (
            <li key={index} className="mb-4 border p-2">
              <p>路线: {reservation.reserved_route}</p>
              <p>时间: {reservation.reserved_time}</p>
              {reservation.qr_code && (
                <img
                  src={
                    reservation.qr_code.startsWith("data:image/")
                      ? reservation.qr_code
                      : `data:image/png;base64,${reservation.qr_code}`
                  }
                  alt="QR Code"
                  className="mt-2 max-w-full h-auto"
                />
              )}
            </li>
          ))}
        </ul>
      ) : (
        <p className="mt-4">没有可用的预约信息</p>
      )}
    </div>
  );
}
