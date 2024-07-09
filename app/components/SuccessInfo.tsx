import QRCode from "qrcode.react";
import { Loader2, BusIcon } from "lucide-react";
import { ReservationResult } from "../types";

interface ResultCardProps {
  reservationResult: ReservationResult;
  handleReverseBus: () => Promise<void>;
  isReverseLoading: boolean;
}
const QRCodeTypeBadge: React.FC<{ qrcodeType: string }> = ({ qrcodeType }) => {
  const isRideCode = qrcodeType === "乘车码";

  const baseClasses = "px-3 py-1 rounded-full text-sm font-medium";
  const colorClasses = isRideCode
    ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-800 dark:text-emerald-200"
    : "bg-yellow-100 text-yellow-800 dark:bg-orange-300/50 dark:text-yellow-200";

  return <span className={`${baseClasses} ${colorClasses}`}>{qrcodeType}</span>;
};

const ResultCard: React.FC<ResultCardProps> = ({
  reservationResult,
  handleReverseBus,
  isReverseLoading,
}) => {
  return (
    <div className="space-y-6">
      <div className="rounded-lg p-4 space-y-3 bg-indigo-50 dark:bg-gray-700">
        <div className="flex justify-between items-center pb-2 border-b border-indigo-200 dark:border-gray-600">
          <h3 className="text-xl font-semibold text-indigo-800 dark:text-indigo-200">
            预约成功
          </h3>
          <QRCodeTypeBadge qrcodeType={reservationResult.qrcode_type} />
        </div>
        <div className="flex justify-between items-center">
          <span className="text-lg text-indigo-600 dark:text-indigo-300">
            班车路线
          </span>
          <span
            className={`font-medium ${
              reservationResult.route_name.length < 10 ? "text-lg" : "text-sm"
            } text-indigo-900 dark:text-indigo-100`}
          >
            {reservationResult.route_name}
          </span>
        </div>
        <div className="flex justify-between items-center">
          <span className="text-lg text-indigo-600 dark:text-indigo-300">
            发车时间
          </span>
          <span className="text-lg font-medium text-indigo-900 dark:text-indigo-100">
            {reservationResult.start_time}
          </span>
        </div>
      </div>
      <div className="flex justify-center">
        <QRCode
          value={reservationResult.qrcode}
          size={256}
          renderAs="svg"
          className="p-2 rounded-lg shadow-md bg-white dark:shadow-white/30"
        />
      </div>
      <button
        onClick={handleReverseBus}
        className="w-full px-6 py-3 text-white text-lg font-semibold rounded-lg transition duration-300 ease-in-out focus:outline-none focus:ring-2 focus:ring-opacity-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-700 focus:ring-indigo-500 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-500"
        disabled={isReverseLoading}
      >
        {isReverseLoading ? (
          <Loader2 className="h-5 w-5 animate-spin" />
        ) : (
          <BusIcon size={24} />
        )}
        <span>{isReverseLoading ? "预约中..." : "乘坐反向班车"}</span>
      </button>
    </div>
  );
};

export default ResultCard;
