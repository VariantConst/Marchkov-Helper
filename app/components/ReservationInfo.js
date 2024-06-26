"use client";
import { useState, useEffect } from "react";
import { RefreshCw } from "lucide-react";

export default function ReservationInfo({ user, reservationData, onRefresh }) {
  const [isMobile, setIsMobile] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [currentQRCode, setCurrentQRCode] = useState(null);

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    checkMobile();
    window.addEventListener("resize", checkMobile);
    return () => window.removeEventListener("resize", checkMobile);
  }, []);

  const openModal = (qrCode) => {
    setCurrentQRCode(qrCode);
    setShowModal(true);
  };

  const closeModal = () => {
    setShowModal(false);
    setCurrentQRCode(null);
  };

  return (
    <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6 flex justify-center items-center w-full">
      <div className="flex flex-col gap-4">
        <div className="w-full flex flex-col justify-between">
          <div>
            <h2 className="text-2xl font-bold text-gray-800 dark:text-white mb-4">
              欢迎, {user.username}
            </h2>
            <p className="text-gray-600 dark:text-gray-300">
              临界时刻:{" "}
              <span className="font-semibold">{user.criticalTime}</span>
            </p>
            <p className="text-gray-600 dark:text-gray-300">
              方向:{" "}
              <span className="font-semibold">
                {user.direction === "toChangping" ? "去昌平" : "去燕园"}
              </span>
            </p>
          </div>
        </div>

        {reservationData &&
        reservationData.success &&
        reservationData.reservations &&
        reservationData.reservations.length > 0 ? (
          reservationData.reservations.map((reservation, index) => (
            <div key={index} className="w-full flex flex-col gap-4">
              <div className="w-full flex flex-col justify-between">
                <div className="flex flex-row items-center justify-between gap-x-2 mb-4">
                  <div className="text-center bg-green-100 text-green-800 dark:bg-green-800 p-2 dark:text-green-100 rounded-lg flex-grow">
                    {reservationData.message}
                  </div>
                  <button
                    onClick={onRefresh}
                    className="self-start p-2 rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-blue-900 dark:text-blue-300 dark:hover:bg-blue-800"
                    title="刷新预约信息"
                  >
                    <RefreshCw size={24} />
                  </button>
                </div>

                <div className="bg-gray-50 dark:bg-gray-700 p-4 rounded-lg">
                  <p className="text-gray-700 dark:text-gray-300 mb-2">
                    路线:{" "}
                    <span className="font-semibold">
                      {reservation.reserved_route}
                    </span>
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    时间:{" "}
                    <span className="font-semibold">
                      {reservation.reserved_time}
                    </span>
                  </p>
                </div>
              </div>
              <div className="w-full flex items-center justify-center">
                {reservation.qr_code && (
                  <img
                    src={
                      reservation.qr_code.startsWith("data:image/")
                        ? reservation.qr_code
                        : `data:image/png;base64,${reservation.qr_code}`
                    }
                    alt="QR Code"
                    className="max-w-full h-auto rounded-lg cursor-pointer"
                    onClick={() => openModal(reservation.qr_code)}
                  />
                )}
              </div>
            </div>
          ))
        ) : (
          <p className="text-gray-600 dark:text-gray-300">没有可用的预约信息</p>
        )}
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          onClick={closeModal}
        >
          <div className="bg-white dark:bg-gray-800 p-6 rounded-lg">
            <img
              src={
                currentQRCode.startsWith("data:image/")
                  ? currentQRCode
                  : `data:image/png;base64,${currentQRCode}`
              }
              alt="QR Code"
              className="w-full h-full max-w-4xl max-h-screen object-contain"
            />
          </div>
        </div>
      )}
    </div>
  );
}
