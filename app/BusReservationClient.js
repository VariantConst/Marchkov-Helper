"use client";

import { useState, useEffect } from "react";
import Image from "next/image";
import { Suspense } from "react";

function QRCodeImage({ src }) {
  return (
    <div className="relative w-64 h-64">
      <Image src={src} alt="QR Code" layout="fill" objectFit="contain" />
    </div>
  );
}

function BusInfoCard({ type, qrCodeSrc, busTime, tempCode }) {
  return (
    <div className="bg-gray-50 p-6 rounded-lg shadow-md">
      <h2 className="text-2xl font-semibold mb-4 text-gray-700">
        {type} {tempCode}
      </h2>
      <p className="mt-4 text-gray-600">
        发车时间: {busTime.slice(-4, -2)}:{busTime.slice(-2)}
      </p>

      <QRCodeImage src={qrCodeSrc} />
    </div>
  );
}

export default function BusReservationClient({
  回寝QRCode,
  回寝BusTime,
  回寝TempCode,
  上班QRCode,
  上班BusTime,
  上班TempCode,
}) {
  const [countdown, setCountdown] = useState(3);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const countdownTimer = setInterval(() => {
      setCountdown((prev) => (prev > 1 ? prev - 1 : 1));
    }, 1200);

    setTimeout(() => {
      clearInterval(countdownTimer);
      setLoading(false);
    }, 3000);

    return () => clearInterval(countdownTimer);
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center w-full h-screen bg-gradient-to-r from-cyan-500 to-blue-500">
        <div className="text-9xl font-bold text-white animate-pulse">
          {countdown}
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col justify-center items-center w-full min-h-screen bg-gradient-to-r from-cyan-500 to-blue-500 p-4">
      <div className="w-full max-w-4xl">
        <div className="relative py-3 sm:mx-auto">
          <div className="absolute inset-0 bg-gradient-to-r from-cyan-400 to-light-blue-500 shadow-lg transform -skew-y-6 sm:skew-y-0 sm:-rotate-6 sm:rounded-3xl"></div>
          <div className="relative px-4 py-10 bg-white shadow-lg sm:rounded-3xl sm:p-20">
            <h1 className="text-4xl font-bold mb-8 text-center text-gray-800">
              班车预约系统
            </h1>
            <div className="flex flex-wrap gap-8">
              {回寝QRCode && (
                <BusInfoCard
                  type="回寝"
                  qrCodeSrc={回寝QRCode}
                  busTime={回寝BusTime}
                  tempCode={回寝TempCode}
                />
              )}
              {上班QRCode && (
                <BusInfoCard
                  type="上班"
                  qrCodeSrc={上班QRCode}
                  busTime={上班BusTime}
                  tempCode={上班TempCode}
                />
              )}
              {!回寝QRCode && !上班QRCode && (
                <div className="text-center text-gray-600">
                  目前没有班车可以乘坐，到时候再来吧～
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
