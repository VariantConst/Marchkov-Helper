// app/components/ReservationInfo.js
"use client";

export default function ReservationInfo({
  user,
  reservationData,
  onLogout,
  onRefresh,
}) {
  return (
    <div className="bg-white shadow rounded-lg p-8">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-800">
          欢迎, {user.username}
        </h2>
        <button
          onClick={onLogout}
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
        >
          登出
        </button>
      </div>
      <div className="mb-6">
        <p className="text-gray-600">
          临界时刻: <span className="font-semibold">{user.criticalTime}</span>
        </p>
        <p className="text-gray-600">
          方向:{" "}
          <span className="font-semibold">
            {user.direction === "toChangping" ? "去昌平" : "去燕园"}
          </span>
        </p>
      </div>
      <div className="mb-6">
        <button
          onClick={onRefresh}
          className="w-full px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          刷新预约信息
        </button>
      </div>
      <div>
        <h3 className="text-xl font-semibold mb-4 text-gray-800">班车信息</h3>
        {reservationData.message && (
          <p
            className={`mb-4 p-3 rounded ${
              reservationData.success
                ? "bg-green-100 text-green-800"
                : "bg-red-100 text-red-800"
            }`}
          >
            {reservationData.message}
          </p>
        )}
        {reservationData.success && reservationData.reservations.length > 0 ? (
          <ul className="space-y-4">
            {reservationData.reservations.map((reservation, index) => (
              <li key={index} className="border rounded-lg p-4 bg-gray-50">
                <p className="text-gray-700">
                  路线:{" "}
                  <span className="font-semibold">
                    {reservation.reserved_route}
                  </span>
                </p>
                <p className="text-gray-700">
                  时间:{" "}
                  <span className="font-semibold">
                    {reservation.reserved_time}
                  </span>
                </p>
                {reservation.qr_code && (
                  <div className="mt-4">
                    <img
                      src={
                        reservation.qr_code.startsWith("data:image/")
                          ? reservation.qr_code
                          : `data:image/png;base64,${reservation.qr_code}`
                      }
                      alt="QR Code"
                      className="mx-auto max-w-full h-auto"
                    />
                  </div>
                )}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-gray-600">没有可用的预约信息</p>
        )}
      </div>
    </div>
  );
}
