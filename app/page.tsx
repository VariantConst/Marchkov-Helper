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
}

const Base64QRCode = ({ base64String }: { base64String: string }) => {
  return (
    <div className="flex justify-center items-center p-4">
      <QRCode value={base64String} size={256} level="H" includeMargin={true} />
    </div>
  );
};

const BusReservation = () => {
  const [loginStatus, setLoginStatus] = useState<boolean | null>(null);
  const [user, setUser] = useState<string | null>(null);
  const [loginErrorMessage, setLoginErrorMessage] = useState("");
  const [possibleBus, setPossibleBus] = useState<BusData | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [reservationData, setReservationData] =
    useState<ReservationData | null>(null);
  const [reservationError, setReservationError] = useState<string | null>(null);
  const [tempQRCode, setTempQRCode] = useState<string | null>(null);
  const [tempQRCodeError, setTempQRCodeError] = useState<string | null>(null);

  const resetModalState = () => {
    setReservationData(null);
    setReservationError(null);
    setTempQRCode(null);
    setTempQRCodeError(null);
  };

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

  const handleReservation = (id: string, bus: Bus) => {
    resetModalState();
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
          });
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

  const handleCancelReservation = () => {
    if (reservationData) {
      const { app_id, app_appointment_id } = reservationData;
      fetch(
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
            resetModalState();
            setShowModal(false); // 直接关闭模态框
            setReservationData(null); // 清除预约数据
            // 可以添加一个临时提示，比如使用toast通知用户预约已取消
          } else {
            setReservationError(`取消预约失败: ${data.message}`);
          }
        })
        .catch((error) => {
          console.error("Cancel reservation error:", error);
          setReservationError("取消预约过程中发生错误，请稍后重试");
        });
    }
  };

  const handleGetTempQRCode = (resourceId: string, startTime: string) => {
    resetModalState();
    fetch(
      `/api/get_temp_qrcode?resource_id=${resourceId}&start_time=${startTime}`
    )
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          setTempQRCode(data.qrcode);
          setTempQRCodeError(null); // 清除临时码错误状态
          setShowModal(true);
        } else {
          setTempQRCodeError(data.message || "获取临时二维码失败");
          setShowModal(true);
        }
      })
      .catch((error) => {
        console.error("获取临时二维码错误:", error);
        setTempQRCodeError("获取临时二维码过程中发生错误，请稍后重试");
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
              {title === "未来可用的班车" && (
                <button
                  onClick={() => handleReservation(id, bus)}
                  className="ml-2 px-2 py-1 bg-blue-500 text-white rounded hover:bg-blue-600"
                >
                  预约
                </button>
              )}
              {title === "已过期的班车" && (
                <button
                  onClick={() => handleGetTempQRCode(id, bus.start_time)}
                  className="ml-2 px-2 py-1 bg-green-500 text-white rounded hover:bg-green-600"
                >
                  获取临时码
                </button>
              )}
            </li>
          ))}
        </ul>
      </div>
    );
  };

  const Modal = ({ onClose }: { onClose: () => void }) => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white p-4 rounded-lg">
        {reservationData ? (
          <>
            <h2 className="text-xl font-bold mb-2">预约成功</h2>
            <Base64QRCode base64String={reservationData.qrcode} />
            <button
              onClick={handleCancelReservation}
              className="mt-4 px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
            >
              取消预约
            </button>
          </>
        ) : tempQRCode ? (
          <>
            <h2 className="text-xl font-bold mb-2">临时二维码</h2>
            <Base64QRCode base64String={tempQRCode} />
          </>
        ) : reservationError || tempQRCodeError ? (
          <>
            <h2 className="text-xl font-bold mb-2">操作失败</h2>
            <p className="text-red-500 mb-4">
              {reservationError || tempQRCodeError}
            </p>
          </>
        ) : null}
        <button
          onClick={onClose}
          className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
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
            <p className="mb-4">可用的班车：</p>
            {possibleBus && (
              <>
                {renderBusList(
                  possibleBus.possible_expired_bus,
                  "已过期的班车"
                )}
                {renderBusList(
                  possibleBus.possible_future_bus,
                  "未来可用的班车"
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
      {showModal && (
        <Modal
          onClose={() => {
            setShowModal(false);
            setReservationError(null); // 清除错误信息
          }}
        />
      )}
    </main>
  );
};

export default BusReservation;
