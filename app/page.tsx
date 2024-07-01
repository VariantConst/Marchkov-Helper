"use client";
import React, { useState, useEffect } from "react";
import QRCode from "qrcode.react";

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

const Base64QRCode = ({ base64String }: { base64String: string }) => {
  return (
    <div className="flex justify-center items-center p-4">
      <QRCode value={base64String} size={256} level="H" includeMargin={true} />
    </div>
  );
};

const AutoBusReservation = () => {
  const [loginStatus, setLoginStatus] = useState<boolean | null>(null);
  const [user, setUser] = useState<string | null>(null);
  const [loginErrorMessage, setLoginErrorMessage] = useState("");
  const [reservationData, setReservationData] =
    useState<ReservationData | null>(null);
  const [reservationError, setReservationError] = useState<string | null>(null);
  const [busData, setBusData] = useState<BusData | null>(null);
  const [isReverse, setIsReverse] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const CRITICAL_TIME = parseInt(process.env.CRITICAL_TIME || "14");

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

  const fetchBusData = () => {
    setIsLoading(true);
    fetch("/api/get_available_bus")
      .then((response) => response.json())
      .then((data) => {
        if (data.success && data.possible_bus) {
          setBusData(data.possible_bus);
          reserveAppropriateBus(data.possible_bus, isReverse);
        } else {
          console.error("Invalid data structure:", data);
          setReservationError("获取班车数据失败");
        }
      })
      .catch((error) => {
        console.error("Error:", error);
        setReservationError("获取班车数据时发生错误");
      })
      .finally(() => setIsLoading(false));
  };

  const reserveAppropriateBus = (busData: BusData, reverse: boolean) => {
    const selectedBus = selectAppropriateBus(busData, reverse);
    if (selectedBus) {
      if (selectedBus.isExpired) {
        getTempQRCode(selectedBus.id, selectedBus.start_time);
      } else {
        makeReservation(selectedBus.id, selectedBus);
      }
    } else {
      setReservationError("没有找到合适的班车");
    }
  };

  const selectAppropriateBus = (busData: BusData, reverse: boolean) => {
    const now = new Date();
    const currentHour = now.getHours();
    let appropriateBuses: (Bus & { isExpired: boolean })[] = [];

    const isCurrentlyReverse = currentHour >= CRITICAL_TIME !== reverse;

    if (!isCurrentlyReverse) {
      // 上班时间或反向下班，选择2或4
      appropriateBuses = Object.entries(busData.possible_future_bus)
        .filter(([id]) => ["2", "4"].includes(id))
        .map(([id, bus]) => ({ ...bus, id: parseInt(id), isExpired: false }));
    } else {
      // 下班时间或反向上班，选择5、6或7
      appropriateBuses = Object.entries(busData.possible_future_bus)
        .filter(([id]) => ["5", "6", "7"].includes(id))
        .map(([id, bus]) => ({ ...bus, id: parseInt(id), isExpired: false }));
    }

    // 如果没有合适的未来班车，检查过期班车
    if (appropriateBuses.length === 0) {
      appropriateBuses = Object.entries(busData.possible_expired_bus).map(
        ([id, bus]) => ({ ...bus, id: parseInt(id), isExpired: true })
      );
    }

    // 选择时间最接近现在的班车
    return appropriateBuses.sort((a, b) => {
      const timeA = new Date(a.start_time).getTime();
      const timeB = new Date(b.start_time).getTime();
      return Math.abs(timeA - now.getTime()) - Math.abs(timeB - now.getTime());
    })[0];
  };

  const makeReservation = (id: number, bus: Bus) => {
    setIsLoading(true);
    const resource_id = id;
    const period = bus.time_id.toString();
    const sub_resource_id = 0;

    const queryParams = new URLSearchParams({
      resource_id: resource_id.toString(),
      period: period,
      sub_resource_id: sub_resource_id.toString(),
    });

    fetch(`/api/reserve_and_get_qrcode?${queryParams.toString()}`, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          setReservationData({
            qrcode: data.qrcode,
            app_id: data.app_id,
            app_appointment_id: data.app_appointment_id,
            bus: bus,
            isTemporary: false,
          });
        } else {
          setReservationError(data.message || "预约失败，请稍后重试");
        }
      })
      .catch((error) => {
        console.error("Reservation error:", error);
        setReservationError("预约过程中发生错误，请稍后重试");
      })
      .finally(() => setIsLoading(false));
  };

  const getTempQRCode = (resourceId: number, startTime: string) => {
    setIsLoading(true);
    fetch(
      `/api/get_temp_qrcode?resource_id=${resourceId}&start_time=${startTime}`
    )
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          setReservationData({
            qrcode: data.qrcode,
            app_id: "",
            app_appointment_id: "",
            bus: {
              id: resourceId,
              name: `班车 ${resourceId}`,
              time_id: 0,
              start_time: startTime,
            },
            isTemporary: true,
          });
        } else {
          setReservationError(data.message || "获取临时二维码失败");
        }
      })
      .catch((error) => {
        console.error("获取临时二维码错误:", error);
        setReservationError("获取临时二维码过程中发生错误，请稍后重试");
      })
      .finally(() => setIsLoading(false));
  };

  const handleCancelReservation = () => {
    if (reservationData && !reservationData.isTemporary) {
      setIsLoading(true);
      const { app_id, app_appointment_id } = reservationData;
      return fetch(
        `/api/cancel_reservation?appointment_id=${app_id}&hall_appointment_data_id=${app_appointment_id}`,
        {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
          },
        }
      )
        .then((response) => response.json())
        .then((data) => {
          if (data.success) {
            console.log("预约已取消");
            return true;
          } else {
            console.error("取消预约失败:", data.message);
            return false;
          }
        })
        .catch((error) => {
          console.error("Cancel reservation error:", error);
          return false;
        })
        .finally(() => setIsLoading(false));
    }
    return Promise.resolve(true);
  };

  const handleReverseBus = async () => {
    setIsLoading(true);

    if (reservationData && !reservationData.isTemporary) {
      const cancelSuccess = await handleCancelReservation();
      if (!cancelSuccess) {
        setReservationError("取消当前预约失败，无法切换班车");
        setIsLoading(false);
        return;
      }
    }

    setIsReverse(!isReverse);

    if (busData) {
      reserveAppropriateBus(busData, !isReverse);
    } else {
      setReservationError("班车数据不可用");
      setIsLoading(false);
    }
  };

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 w-full max-w-5xl items-center justify-between font-mono text-sm lg:flex">
        {loginStatus === null ? (
          <p>正在加载...</p>
        ) : loginStatus ? (
          <div>
            <h1 className="text-2xl font-bold mb-4">欢迎：{user}</h1>
            {isLoading ? (
              <p>正在加载班车信息...</p>
            ) : reservationData ? (
              <div>
                <h2 className="text-xl mb-2">预约成功</h2>
                <p>班车ID: {reservationData.bus.id}</p>
                <p>班车名称: {reservationData.bus.name}</p>
                <p>出发时间: {reservationData.bus.start_time}</p>
                <p>
                  二维码类型:{" "}
                  {reservationData.isTemporary ? "临时码" : "乘车码"}
                </p>
                <Base64QRCode base64String={reservationData.qrcode} />
                <button
                  onClick={handleReverseBus}
                  className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
                  disabled={isLoading}
                >
                  切换到{isReverse ? "上班" : "下班"}班车
                </button>
              </div>
            ) : reservationError ? (
              <p className="text-red-500">{reservationError}</p>
            ) : (
              <p>正在为您预约班车...</p>
            )}
          </div>
        ) : (
          <div>
            <h1 className="text-2xl font-bold mb-4">登录失败</h1>
            <p className="text-red-500">{loginErrorMessage}</p>
            <p className="mt-4">请到Vercel后台修改环境变量并重新部署。</p>
          </div>
        )}
      </div>
    </main>
  );
};

export default AutoBusReservation;
