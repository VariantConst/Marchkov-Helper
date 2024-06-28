// app/components/ReservationInfo.js
"use client";
import { useState, useEffect } from "react";
import { RefreshCw, MapPin, Clock, Settings } from "lucide-react";

export default function ReservationInfo({ user, reservationData }) {
  const [showModal, setShowModal] = useState(false);
  const [currentQRCode, setCurrentQRCode] = useState(null);

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
        <div className="w-full">
          <div className="flex flex-col space-y-1">
            {/* <h2 className="text-3xl font-light text-gray-800 dark:text-gray-200 border-b border-gray-200 pb-2 mb-6">
              欢迎,{" "}
              <span className="font-normal text-gray-600 dark:text-gray-300">
                {user.username}
              </span>
            </h2> */}
            <div className="flex items-center space-x-2 text-gray-600 dark:text-gray-300">
              <MapPin className="w-4 h-4" />
              <p>
                早上去
                {user.direction === "toChangping" ? "昌平💤" : "燕园💻"} 晚上回
                {user.direction === "toChangping" ? "燕园💻" : "昌平💤"}
              </p>
            </div>
            <div className="flex items-center space-x-2 text-gray-600 dark:text-gray-300">
              <Clock className="w-4 h-4" />
              <p>
                临界时刻:{" "}
                <span className="font-semibold">{user.criticalTime}</span>
              </p>
            </div>
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
          <p className="text-gray-600 dark:text-gray-300">
            这会没有班车可坐。急了？😅
          </p>
        )}
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 backdrop-filter backdrop-blur-sm"
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
