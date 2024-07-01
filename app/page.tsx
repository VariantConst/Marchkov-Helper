"use client";
import React, { useState, useEffect } from "react";
import QRCode from "qrcode.react";
import { Loader2, Bus, Sun, Moon } from "../node_modules/lucide-react";

interface Bus {
  id: number;
  name: string;
  time_id: number;
  start_time: string;
}

interface BusData {
  possible_expired_bus: { [key: string]: Bus };
  possible_future_bus: { [key: string]: Bus };
}

interface ReservationData {
  qrcode: string;
  app_id: string;
  app_appointment_id: string;
  bus: Bus;
  isTemporary: boolean;
}

const Base64QRCode: React.FC<{ base64String: string }> = ({ base64String }) => {
  return (
    <div className="flex justify-center items-center p-4">
      <QRCode value={base64String} size={256} level="H" includeMargin={true} />
    </div>
  );
};

const AutoBusReservation: React.FC = () => {
  const [loginStatus, setLoginStatus] = useState<boolean | null>(null);
  const [user, setUser] = useState<string | null>(null);
  const [loginErrorMessage, setLoginErrorMessage] = useState<string>("");
  const [reservationData, setReservationData] =
    useState<ReservationData | null>(null);
  const [reservationError, setReservationError] = useState<string | null>(null);
  const [busData, setBusData] = useState<BusData | null>(null);
  const [isReverse, setIsReverse] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(false);

  const [darkMode, setDarkMode] = useState(false);

  useEffect(() => {
    if (darkMode) {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  }, [darkMode]);

  const toggleDarkMode = () => {
    setDarkMode(!darkMode);
  };

  const CRITICAL_TIME = parseInt(process.env.NEXT_PUBLIC_CRITICAL_TIME || "14");

  useEffect(() => {
    fetch("/api/login")
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          setLoginStatus(true);
          setUser(data.username);
          fetchBusData();
        } else {
          setLoginStatus(false);
          setLoginErrorMessage(data.message);
        }
      })
      .catch((error) => {
        setLoginStatus(false);
        setLoginErrorMessage("发生错误，请稍后再试");
        console.error("Error:", error);
      });
  }, []);

  const fetchBusData = async () => {
    setIsLoading(true);
    try {
      const response = await fetch("/api/get_available_bus");
      const data = await response.json();
      if (data.success && data.possible_bus) {
        console.log("Fetched bus data:", data.possible_bus);
        setBusData(data.possible_bus);
        await reserveAppropriateBus(data.possible_bus, isReverse);
      } else {
        console.error("Invalid data structure:", data);
        setReservationError("获取班车数据失败");
      }
    } catch (error) {
      console.error("Error:", error);
      setReservationError("获取班车数据时发生错误");
    } finally {
      setIsLoading(false);
    }
  };

  const selectAppropriateBus = (
    busData: BusData,
    reverse: boolean
  ): { bus: Bus; isExpired: boolean } | null => {
    const now = new Date();
    const upwardIds = ["2", "4"];
    const downwardIds = ["5", "6", "7"];
    const targetIds = reverse ? downwardIds : upwardIds;

    // 首先检查过期班车
    let selectedBus = Object.entries(busData.possible_expired_bus)
      .filter(([id]) => targetIds.includes(id))
      .map(([id, bus]) => ({
        bus: { ...bus, id: parseInt(id) },
        isExpired: true,
      }))
      .sort((a, b) => {
        const timeA = new Date(`1970-01-01T${a.bus.start_time}`).getTime();
        const timeB = new Date(`1970-01-01T${b.bus.start_time}`).getTime();
        return timeB - timeA;
      })[0];

    // 如果没有找到合适的过期班车，检查未来班车
    if (!selectedBus) {
      selectedBus = Object.entries(busData.possible_future_bus)
        .filter(([id]) => targetIds.includes(id))
        .map(([id, bus]) => ({
          bus: { ...bus, id: parseInt(id) },
          isExpired: false,
        }))
        .sort((a, b) => {
          const timeA = new Date(`1970-01-01T${a.bus.start_time}`).getTime();
          const timeB = new Date(`1970-01-01T${b.bus.start_time}`).getTime();
          return timeA - timeB;
        })[0];
    }

    console.log("Selected bus:", selectedBus);
    return selectedBus || null;
  };

  const reserveAppropriateBus = async (busData: BusData, reverse: boolean) => {
    const selectedBus = selectAppropriateBus(busData, reverse);
    if (selectedBus) {
      console.log("Reserving bus:", selectedBus);
      if (selectedBus.isExpired) {
        const tempQRCode = await getTempQRCode(
          selectedBus.bus.id,
          selectedBus.bus.start_time,
          selectedBus.bus
        );
        if (tempQRCode) {
          setReservationData(tempQRCode);
        }
      } else {
        const reservationResult = await makeReservation(
          selectedBus.bus.id,
          selectedBus.bus
        );
        if (reservationResult) {
          setReservationData(reservationResult);
        }
      }
    } else {
      setReservationError("没有找到合适的班车");
    }
  };

  const makeReservation = async (id: number, bus: Bus) => {
    try {
      const resource_id = id;
      const period = bus.time_id.toString();
      const sub_resource_id = 0;

      const queryParams = new URLSearchParams({
        resource_id: resource_id.toString(),
        period: period,
        sub_resource_id: sub_resource_id.toString(),
      });

      const response = await fetch(
        `/api/reserve_and_get_qrcode?${queryParams.toString()}`
      );
      const data = await response.json();
      if (data.success) {
        return {
          qrcode: data.qrcode,
          app_id: data.app_id,
          app_appointment_id: data.app_appointment_id,
          bus: bus,
          isTemporary: false,
        };
      } else {
        setReservationError(data.message || "预约失败，请稍后重试");
        return null;
      }
    } catch (error) {
      console.error("Reservation error:", error);
      setReservationError("预约过程中发生错误，请稍后重试");
      return null;
    }
  };

  const getTempQRCode = async (
    resourceId: number,
    startTime: string,
    bus: Bus
  ) => {
    try {
      const response = await fetch(
        `/api/get_temp_qrcode?resource_id=${resourceId}&start_time=${startTime}`
      );
      const data = await response.json();
      if (data.success) {
        return {
          qrcode: data.qrcode,
          app_id: "",
          app_appointment_id: "",
          bus: bus,
          isTemporary: true,
        };
      } else {
        setReservationError(data.message || "获取临时二维码失败");
        return null;
      }
    } catch (error) {
      console.error("获取临时二维码错误:", error);
      setReservationError("获取临时二维码过程中发生错误，请稍后重试");
      return null;
    }
  };

  const cancelReservation = async (
    app_id: string,
    app_appointment_id: string
  ) => {
    try {
      const response = await fetch(
        `/api/cancel_reservation?appointment_id=${app_id}&hall_appointment_data_id=${app_appointment_id}`
      );
      const data = await response.json();
      if (data.success) {
        console.log("Reservation cancelled successfully");
        return true;
      } else {
        console.error("Failed to cancel reservation:", data.message);
        return false;
      }
    } catch (error) {
      console.error("Error cancelling reservation:", error);
      return false;
    }
  };

  const handleReverseBus = async () => {
    setIsLoading(true);
    const newIsReverse = !isReverse;
    setIsReverse(newIsReverse);

    try {
      // 如果当前有非临时的预约，先取消它
      if (reservationData && !reservationData.isTemporary) {
        const cancelSuccess = await cancelReservation(
          reservationData.app_id,
          reservationData.app_appointment_id
        );
        if (!cancelSuccess) {
          setReservationError("取消当前预约失败，无法切换班车");
          setIsLoading(false);
          return;
        }
      }

      const response = await fetch("/api/get_available_bus");
      const data = await response.json();
      if (data.success && data.possible_bus) {
        console.log("Fetched bus data for reverse:", data.possible_bus);
        setBusData(data.possible_bus);
        await reserveAppropriateBus(data.possible_bus, newIsReverse);
      } else {
        setReservationError("获取最新班车数据失败");
      }
    } catch (error) {
      console.error("Error:", error);
      setReservationError("获取班车数据时发生错误");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <main
      className={`min-h-screen flex items-center justify-center p-4 ${
        darkMode
          ? "bg-gray-900"
          : "bg-gradient-to-br from-blue-50 to-indigo-100"
      }`}
    >
      <div
        className={`rounded-xl shadow-lg p-6 max-w-md w-full ${
          darkMode ? "bg-gray-800" : "bg-white"
        }`}
      >
        {loginStatus && (
          <div
            className={`mb-4 pb-3 border-b flex justify-between items-center ${
              darkMode ? "border-gray-700" : "border-indigo-100"
            }`}
          >
            <p
              className={`text-lg ${
                darkMode ? "text-indigo-300" : "text-indigo-600"
              }`}
            >
              欢迎回来，
              <span
                className={`font-semibold ${
                  darkMode ? "text-indigo-200" : "text-indigo-800"
                }`}
              >
                {user}
              </span>
            </p>
            <button
              onClick={toggleDarkMode}
              className={`p-2 rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                darkMode
                  ? "bg-gray-700 text-white focus:ring-gray-500"
                  : "bg-gray-200 text-gray-800 focus:ring-gray-300"
              }`}
            >
              {darkMode ? <Sun size={20} /> : <Moon size={20} />}
            </button>
          </div>
        )}
        {loginStatus === null ? (
          <div className="flex items-center justify-center space-x-3">
            <Loader2
              className={`h-8 w-8 animate-spin ${
                darkMode ? "text-indigo-300" : "text-indigo-500"
              }`}
            />
            <p
              className={`text-xl ${
                darkMode ? "text-indigo-300" : "text-indigo-600"
              }`}
            >
              正在加载...
            </p>
          </div>
        ) : loginStatus ? (
          <div>
            {isLoading ? (
              <div className="flex flex-col items-center space-y-3">
                <Loader2
                  className={`h-12 w-12 animate-spin ${
                    darkMode ? "text-indigo-300" : "text-indigo-500"
                  }`}
                />
                <p
                  className={`text-xl ${
                    darkMode ? "text-indigo-300" : "text-indigo-600"
                  }`}
                >
                  正在加载班车信息...
                </p>
              </div>
            ) : reservationData ? (
              <div className="space-y-6">
                <div
                  className={`rounded-lg p-4 space-y-3 ${
                    darkMode ? "bg-gray-700" : "bg-indigo-50"
                  }`}
                >
                  <div
                    className={`flex justify-between items-center pb-2 border-b ${
                      darkMode ? "border-gray-600" : "border-indigo-200"
                    }`}
                  >
                    <h3
                      className={`text-xl font-semibold ${
                        darkMode ? "text-indigo-200" : "text-indigo-800"
                      }`}
                    >
                      班车信息
                    </h3>
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-medium ${
                        reservationData.isTemporary
                          ? darkMode
                            ? "bg-amber-800 text-amber-200"
                            : "bg-amber-100 text-amber-800"
                          : darkMode
                          ? "bg-emerald-800 text-emerald-200"
                          : "bg-emerald-100 text-emerald-800"
                      }`}
                    >
                      {reservationData.isTemporary ? "临时码" : "乘车码"}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span
                      className={`text-lg w-2/5 text-left ${
                        darkMode ? "text-indigo-300" : "text-indigo-600"
                      }`}
                    >
                      班车名称
                    </span>
                    <span
                      className={`text-lg font-medium w-3/5 text-right ${
                        darkMode ? "text-indigo-100" : "text-indigo-900"
                      }`}
                    >
                      {reservationData.bus.name}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span
                      className={`text-lg ${
                        darkMode ? "text-indigo-300" : "text-indigo-600"
                      }`}
                    >
                      出发时间
                    </span>
                    <span
                      className={`text-lg font-medium ${
                        darkMode ? "text-indigo-100" : "text-indigo-900"
                      }`}
                    >
                      {reservationData.bus.start_time}
                    </span>
                  </div>
                </div>
                <div className="flex justify-center">
                  <div
                    className={`p-2 rounded-lg shadow-md ${
                      darkMode ? "bg-gray-700" : "bg-white"
                    }`}
                  >
                    <Base64QRCode base64String={reservationData.qrcode} />
                  </div>
                </div>
                <button
                  onClick={handleReverseBus}
                  className={`w-full px-6 py-3 text-white text-lg font-semibold rounded-lg transition duration-300 ease-in-out focus:outline-none focus:ring-2 focus:ring-opacity-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2 ${
                    darkMode
                      ? "bg-blue-600 hover:bg-blue-700 focus:ring-blue-500"
                      : "bg-indigo-600 hover:bg-indigo-700 focus:ring-indigo-500"
                  }`}
                  disabled={isLoading}
                >
                  <Bus size={24} />
                  <span>乘坐反向班车</span>
                </button>
              </div>
            ) : reservationError ? (
              <p
                className={`text-xl text-center font-medium ${
                  darkMode ? "text-red-400" : "text-red-600"
                }`}
              >
                {reservationError}
              </p>
            ) : (
              <p
                className={`text-xl text-center ${
                  darkMode ? "text-indigo-300" : "text-indigo-600"
                }`}
              >
                正在为您预约班车...
              </p>
            )}
          </div>
        ) : (
          <div className="text-center space-y-3">
            <h1
              className={`text-2xl font-bold mb-3 ${
                darkMode ? "text-indigo-200" : "text-indigo-800"
              }`}
            >
              登录失败
            </h1>
            <p
              className={`text-xl mb-3 ${
                darkMode ? "text-indigo-300" : "text-indigo-600"
              }`}
            >
              {loginErrorMessage}
            </p>
            <p
              className={`text-lg ${
                darkMode ? "text-indigo-400" : "text-indigo-500"
              }`}
            >
              请到Vercel后台修改环境变量并重新部署。
            </p>
          </div>
        )}
      </div>
    </main>
  );
};

export default AutoBusReservation;
