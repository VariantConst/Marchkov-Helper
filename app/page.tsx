"use client";
import React, { useState, useEffect } from "react";
import QRCode from "qrcode.react";
import { Loader2, Bus, Sun, Moon, Github } from "../node_modules/lucide-react";
import Toast from "./components/Toast";

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
  const [toastVisible, setToastVisible] = useState(false);
  const [toastMessage, setToastMessage] = useState("");

  const CRITICAL_TIME = parseInt(process.env.NEXT_PUBLIC_CRITICAL_TIME || "14");
  const FLAG_MORNING_TO_YANYUAN: boolean =
    process.env.NEXT_PUBLIC_FLAG_MORNING_TO_YANYUAN === "1";
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
    const hour = now.getHours();
    console.log("FLAG_MORNING_TO_YANYUAN =", FLAG_MORNING_TO_YANYUAN);
    const isToYanyuan = FLAG_MORNING_TO_YANYUAN
      ? hour < CRITICAL_TIME
      : hour >= CRITICAL_TIME;
    const toYuanyuanIds = ["2", "4"];
    const toChangpingIds = ["5", "6", "7"];
    const targetIds = reverse
      ? isToYanyuan
        ? toChangpingIds
        : toYuanyuanIds
      : isToYanyuan
      ? toYuanyuanIds
      : toChangpingIds;

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
      return true;
    } else {
      console.error("No appropriate bus found");
      setReservationError("没有找到合适的班车");
      return null;
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
      if (busData) {
        const isReserveSuccess = await reserveAppropriateBus(
          busData,
          newIsReverse
        );
        if (!isReserveSuccess) {
          setReservationError("切换班车失败");
          console.error("反向没有班车可坐！");
          setToastMessage("相反方向没有班车可坐！");
          setToastVisible(true);
        }
      } else {
        setReservationError("无法获取班车数据");
        console.error("班车数据不可用");
        setToastMessage("无法获取班车数据，请稍后重试");
        setToastVisible(true);
      }
    } catch (error) {
      console.error("Error:", error);
      setReservationError("获取班车数据时发生错误");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <main className="min-h-screen flex flex-col items-center sm:justify-center p-4 bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-zinc-800 dark:to-slate-900">
      <div className="rounded-xl shadow-lg p-6 max-w-md w-full bg-white dark:bg-gray-800">
        {loginStatus && (
          <div className="mb-4 pb-3 border-b border-indigo-100 dark:border-gray-700 flex justify-between items-center">
            <p className="text-lg text-indigo-600 dark:text-indigo-300">
              欢迎，
              <span className="font-semibold text-indigo-800 dark:text-indigo-200">
                {user}
              </span>
            </p>
            <div className="flex items-center space-x-2">
              <a
                href="https://github.com/VariantConst/3-2-1-Marchkov"
                target="_blank"
                rel="noopener noreferrer"
                className="p-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 dark:focus:ring-gray-500"
              >
                <Github size={20} />
              </a>
              <button
                onClick={() =>
                  document.documentElement.classList.toggle("dark")
                }
                className="p-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 dark:focus:ring-gray-500"
              >
                <Sun size={20} className="hidden dark:block" />
                <Moon size={20} className="block dark:hidden" />
              </button>
            </div>
          </div>
        )}
        {loginStatus === null ? (
          <div className="flex items-center justify-center space-x-3">
            <Loader2 className="h-8 w-8 animate-spin text-indigo-500 dark:text-indigo-300" />
            <p className="text-xl text-indigo-600 dark:text-indigo-300">
              正在加载...
            </p>
          </div>
        ) : loginStatus ? (
          <div>
            {isLoading ? (
              <div className="flex flex-col items-center space-y-3">
                <Loader2 className="h-12 w-12 animate-spin text-indigo-500 dark:text-indigo-300" />
                <p className="text-xl text-indigo-600 dark:text-indigo-300">
                  正在加载班车信息...
                </p>
              </div>
            ) : reservationData ? (
              <div className="space-y-6">
                <div className="rounded-lg p-4 space-y-3 bg-indigo-50 dark:bg-gray-700">
                  <div className="flex justify-between items-center pb-2 border-b border-indigo-200 dark:border-gray-600">
                    <h3 className="text-xl font-semibold text-indigo-800 dark:text-indigo-200">
                      预约成功
                    </h3>
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-medium ${
                        reservationData.isTemporary
                          ? "bg-amber-100 text-amber-800 dark:bg-amber-800 dark:text-amber-200"
                          : "bg-emerald-100 text-emerald-800 dark:bg-emerald-800 dark:text-emerald-200"
                      }`}
                    >
                      {reservationData.isTemporary ? "临时码" : "乘车码"}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-lg w-2/5 text-left text-indigo-600 dark:text-indigo-300">
                      班车路线
                    </span>
                    <span
                      className={`${
                        reservationData.bus.name.length < 10
                          ? "text-lg"
                          : "text-xs"
                      } font-medium w-3/5 text-right text-indigo-900 dark:text-indigo-100`}
                    >
                      {reservationData.bus.name}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-lg text-indigo-600 dark:text-indigo-300">
                      发车时间
                    </span>
                    <span className="text-lg font-medium text-indigo-900 dark:text-indigo-100">
                      {reservationData.bus.start_time}
                    </span>
                  </div>
                </div>
                <div className="flex justify-center">
                  <QRCode
                    value={reservationData.qrcode}
                    size={256}
                    level="H"
                    includeMargin={true}
                    className="rounded-lg shadow-lg dark:shadow-slate-300/30"
                  />
                </div>
                <button
                  onClick={handleReverseBus}
                  className="w-full px-6 py-3 text-white text-lg font-semibold rounded-lg transition duration-300 ease-in-out focus:outline-none focus:ring-2 focus:ring-opacity-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-700 focus:ring-indigo-500 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-500"
                  disabled={isLoading}
                >
                  <Bus size={24} />
                  <span>乘坐反向班车</span>
                </button>
              </div>
            ) : reservationError ? (
              <p className="text-lg text-center font-medium text-indigo-500 dark:text-indigo-400">
                <p className="text-8xl py-4">😅</p>
                这会没有班车可坐。急了？
              </p>
            ) : (
              <p className="text-xl text-center text-indigo-600 dark:text-indigo-300">
                正在为您预约班车...
              </p>
            )}
          </div>
        ) : (
          <div className="text-center space-y-3">
            <h1 className="text-2xl font-bold mb-3 text-indigo-800 dark:text-indigo-200">
              <p className="text-8xl py-4">😇</p>
              登录失败
            </h1>
            <p className="text-lg text-indigo-500 dark:text-indigo-400">
              请修改环境变量并重新部署。
            </p>
          </div>
        )}
        <Toast
          message={toastMessage}
          isVisible={toastVisible}
          onClose={() => setToastVisible(false)}
        />
      </div>
    </main>
  );
};

export default AutoBusReservation;
