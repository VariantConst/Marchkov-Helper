import React from "react";
import { Github, Sun, Moon } from "lucide-react";
import SplashScreen from "./SplashScreen";
import PageLogin from "./PageLogin";
import ResultCard from "./SuccessInfo";
import { ReservationResult } from "../types";

interface BusReservationContentProps {
  isLoading: boolean;
  showSplash: boolean;
  errorMessage: string;
  isAuthenticated: boolean;
  username: string;
  reservationResult: ReservationResult | null;
  isDarkMode: boolean;
  isReverseLoading: boolean;
  handleLogin: (event: React.FormEvent<HTMLFormElement>) => Promise<void>;
  handleReverseBus: () => Promise<void>;
  toggleDarkMode: () => void;
}

const BusReservationContent: React.FC<BusReservationContentProps> = ({
  isLoading,
  showSplash,
  errorMessage,
  isAuthenticated,
  username,
  reservationResult,
  isDarkMode,
  isReverseLoading,
  handleLogin,
  handleReverseBus,
  toggleDarkMode,
}) => {
  const renderContent = () => {
    if (isLoading || showSplash) {
      return <SplashScreen />;
    }

    if (errorMessage) {
      const emoji = errorMessage.includes("环境变量") ? "😇" : "😅";
      return (
        <div className="rounded-lg p-4 space-y-3 text-center">
          <p className="text-8xl">{emoji}</p>
          <p className="text-red-600 dark:text-red-300">{errorMessage}</p>
        </div>
      );
    }

    if (!isAuthenticated) {
      return <PageLogin handleLogin={handleLogin} />;
    }

    if (reservationResult) {
      return (
        <ResultCard
          reservationResult={reservationResult}
          handleReverseBus={handleReverseBus}
          isReverseLoading={isReverseLoading}
        />
      );
    }

    return null;
  };

  return (
    <div className="rounded-xl shadow-lg p-6 max-w-md w-full bg-white dark:bg-gray-800">
      {isAuthenticated && (
        <div className="mb-4 pb-3 border-b border-indigo-100 dark:border-gray-700 flex justify-between items-center">
          <p className="text-lg text-indigo-600 dark:text-indigo-300">
            欢迎，<span className="font-semibold">{username}</span>
          </p>
          <div className="flex items-center space-x-2">
            <a
              href="https://github.com/VariantConst/3-2-1-Marchkov/"
              target="_blank"
              rel="noopener noreferrer"
              className="p-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 dark:focus:ring-gray-500"
            >
              <Github size={20} />
            </a>
            <button
              onClick={toggleDarkMode}
              className="p-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 dark:focus:ring-gray-500"
            >
              {isDarkMode ? <Sun size={20} /> : <Moon size={20} />}
            </button>
          </div>
        </div>
      )}
      {renderContent()}
    </div>
  );
};

export default BusReservationContent;
