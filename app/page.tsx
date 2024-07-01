"use client";
import React, { useState, useEffect } from "react";

interface Bus {
  name: string;
  time_id: number;
  start_time: string;
}

interface BusData {
  possible_expired_bus: { [key: string]: Bus };
  possible_future_bus: { [key: string]: Bus };
}

const BusReservation = () => {
  const [loginStatus, setLoginStatus] = useState<boolean | null>(null);
  const [user, setUser] = useState<string | null>(null);
  const [loginErrorMessage, setLoginErrorMessage] = useState("");
  const [possibleBus, setPossibleBus] = useState<BusData | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [qrCode, setQrCode] = useState<string | null>(null);
  const [reservationError, setReservationError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/login")
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          setLoginStatus(true);
          setUser(data.username);
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

    fetch("/api/get_available_bus")
      .then((response) => response.json())
      .then((data) => {
        if (data.success && data.possible_bus) {
          setPossibleBus(data.possible_bus);
        } else {
          console.error("Invalid data structure:", data);
        }
      })
      .catch((error) => {
        console.error("Error:", error);
      });
  }, []);

  const handleReservation = (bus: Bus) => {
    const resource_id = bus.time_id;
    const period = "47";
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
          setQrCode(data.qrcode);
          setShowModal(true);
        } else {
          setReservationError(data.message || "预约失败，请稍后重试");
          setShowModal(true);
        }
      })
      .catch((error) => {
        console.error("Reservation error:", error);
        setReservationError("预约过程中发生错误，请稍后重试");
        setShowModal(true);
      });
  };

  const renderBusList = (
    buses: { [key: string]: Bus } | undefined,
    title: string
  ) => {
    if (!buses || Object.keys(buses).length === 0) {
      return (
        <div className="mb-4">
          <h3 className="text-lg font-semibold mb-2">{title}</h3>
          <p>暂无数据</p>
        </div>
      );
    }

    return (
      <div className="mb-4">
        <h3 className="text-lg font-semibold mb-2">{title}</h3>
        <ul>
          {Object.entries(buses).map(([id, bus]) => (
            <li key={id} className="mb-1">
              <span className="font-medium">{bus.name}</span> - 出发时间:{" "}
              {bus.start_time}
              {title === "未来可用的公交车" && (
                <button
                  onClick={() => handleReservation(bus)}
                  className="ml-2 px-2 py-1 bg-blue-500 text-white rounded hover:bg-blue-600"
                >
                  预约
                </button>
              )}
            </li>
          ))}
        </ul>
      </div>
    );
  };

  const Modal = ({ onClose }: { onClose: () => void }) => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-4 rounded-lg">
        {qrCode ? (
          <>
            <h2 className="text-xl font-bold mb-2">预约成功</h2>
            <img
              src={`data:image/png;base64,${qrCode}`}
              alt="QR Code"
              className="mb-4"
            />
          </>
        ) : (
          <>
            <h2 className="text-xl font-bold mb-2">预约失败</h2>
            <p className="text-red-500 mb-4">{reservationError}</p>
          </>
        )}
        <button
          onClick={onClose}
          className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          关闭
        </button>
      </div>
    </div>
  );

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 w-full max-w-5xl items-center justify-between font-mono text-sm lg:flex">
        {loginStatus === null ? (
          <p>正在加载...</p>
        ) : loginStatus ? (
          <div>
            <h1 className="text-2xl font-bold mb-4">登录成功</h1>
            <h2 className="text-xl mb-2">欢迎：{user}</h2>
            <p className="mb-4">可用的公交车：</p>
            {possibleBus && (
              <>
                {renderBusList(
                  possibleBus.possible_expired_bus,
                  "已过期的公交车"
                )}
                {renderBusList(
                  possibleBus.possible_future_bus,
                  "未来可用的公交车"
                )}
              </>
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
      {showModal && <Modal onClose={() => setShowModal(false)} />}
    </main>
  );
};

export default BusReservation;
