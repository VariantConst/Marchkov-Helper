// app/components/LoginForm.js
import { useState, useEffect } from "react";
import {
  ChevronRightIcon,
  ClockIcon,
  MapPinIcon,
  RepeatIcon,
} from "lucide-react";

export default function LoginForm({ onSubmit }) {
  const [currentTime, setCurrentTime] = useState("");
  const [currentSliderValue, setCurrentSliderValue] = useState(0);
  const [criticalTime, setCriticalTime] = useState("14:00");
  const [criticalSliderValue, setCriticalSliderValue] = useState(840);
  const [selectedDirection, setSelectedDirection] = useState("toYanyuan");

  useEffect(() => {
    const updateTime = () => {
      const now = new Date(
        new Date().toLocaleString("en-US", { timeZone: "Asia/Shanghai" })
      );
      const hours = String(now.getHours()).padStart(2, "0");
      const minutes = String(now.getMinutes()).padStart(2, "0");
      const newTime = `${hours}:${minutes}`;
      setCurrentTime(newTime);
      setCurrentSliderValue(now.getHours() * 60 + now.getMinutes());
    };

    updateTime();
  }, []);

  const handleCurrentSliderChange = (e) => {
    const value = parseInt(e.target.value);
    setCurrentSliderValue(value);
    const hours = Math.floor(value / 60);
    const minutes = value % 60;
    setCurrentTime(
      `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`
    );
  };

  const handleCriticalSliderChange = (e) => {
    const value = parseInt(e.target.value);
    setCriticalSliderValue(value);
    const hours = Math.floor(value / 60);
    const minutes = value % 60;
    setCriticalTime(
      `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`
    );
  };

  const handleDirectionSwap = () => {
    setSelectedDirection((prevDirection) =>
      prevDirection === "toYanyuan" ? "toChangping" : "toYanyuan"
    );
  };

  return (
    <div className="bg-white dark:bg-gray-800 shadow-lg rounded-xl p-8 max-w-md mx-auto transition-all duration-300 ease-in-out transform hover:shadow-xl">
      <h2 className="text-3xl font-bold mb-8 text-center text-gray-800 dark:text-white">
        用户登录
      </h2>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          const formData = new FormData(e.target);
          formData.append("direction", selectedDirection);
          formData.append("currentTime", currentTime);
          formData.append("criticalTime", criticalTime);
          onSubmit(formData);
        }}
        className="space-y-6"
      >
        <div className="group">
          <label
            htmlFor="username"
            className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 transition-colors duration-200 ease-in-out group-hover:text-blue-600 dark:group-hover:text-blue-400"
          >
            用户名
          </label>
          <div className="relative">
            <input
              type="text"
              name="username"
              id="username"
              required
              className="block w-full border border-gray-300 dark:border-gray-600 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 ease-in-out bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
            <ChevronRightIcon className="absolute right-3 top-2.5 h-5 w-5 text-gray-400 transition-colors duration-200 ease-in-out group-hover:text-blue-600 dark:group-hover:text-blue-400" />
          </div>
        </div>

        <div className="group">
          <label
            htmlFor="password"
            className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 transition-colors duration-200 ease-in-out group-hover:text-blue-600 dark:group-hover:text-blue-400"
          >
            密码
          </label>
          <div className="relative">
            <input
              type="password"
              name="password"
              id="password"
              required
              className="block w-full border border-gray-300 dark:border-gray-600 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 ease-in-out bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
            <ChevronRightIcon className="absolute right-3 top-2.5 h-5 w-5 text-gray-400 transition-colors duration-200 ease-in-out group-hover:text-blue-600 dark:group-hover:text-blue-400" />
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2 flex items-center">
              <ClockIcon className="mr-2 h-5 w-5 text-blue-500 dark:text-blue-400" />
              当前时间: {currentTime}
            </label>
            <input
              type="range"
              min="0"
              max="1439"
              value={currentSliderValue}
              onChange={handleCurrentSliderChange}
              className="w-full h-2 bg-blue-200 dark:bg-blue-700 rounded-lg appearance-none cursor-pointer range-blue"
            />
            <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-1">
              <span>00:00</span>
              <span>12:00</span>
              <span>23:59</span>
            </div>
          </div>

          <div>
            <label
              htmlFor="criticalTime"
              className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2 flex items-center"
            >
              <ClockIcon className="mr-2 h-5 w-5 text-blue-500 dark:text-blue-400" />
              临界时间: {criticalTime}
              <button
                type="button"
                onClick={handleDirectionSwap}
                className="ml-2 p-1 rounded-full bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors duration-200 ease-in-out"
              >
                <RepeatIcon className="h-5 w-5 text-gray-700 dark:text-gray-300" />
              </button>
            </label>
            <div className="relative mb-4">
              <div className="flex justify-between text-sm text-gray-700 dark:text-gray-300 mb-2">
                <span
                  className={
                    selectedDirection === "toYanyuan"
                      ? "text-blue-500"
                      : "text-green-500"
                  }
                >
                  {selectedDirection === "toYanyuan" ? "去燕园" : "去昌平"}
                </span>
                <span
                  className={
                    selectedDirection === "toYanyuan"
                      ? "text-green-500"
                      : "text-blue-500"
                  }
                >
                  {selectedDirection === "toYanyuan" ? "去昌平" : "去燕园"}
                </span>
              </div>
              <div className="relative w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg overflow-visible">
                <div
                  className={`absolute top-0 left-0 h-full rounded-l-lg ${
                    selectedDirection === "toYanyuan"
                      ? "bg-blue-500"
                      : "bg-green-500"
                  } dark:bg-opacity-80`}
                  style={{ width: `${(criticalSliderValue / 1439) * 100}%` }}
                ></div>
                <div
                  className={`absolute top-0 right-0 h-full rounded-r-lg ${
                    selectedDirection === "toYanyuan"
                      ? "bg-green-500"
                      : "bg-blue-500"
                  } dark:bg-opacity-80`}
                  style={{
                    width: `${100 - (criticalSliderValue / 1439) * 100}%`,
                  }}
                ></div>
                <input
                  type="range"
                  min="0"
                  max="1439"
                  value={criticalSliderValue}
                  onChange={handleCriticalSliderChange}
                  className={`absolute top-[-4px] left-0 w-full h-4 cursor-pointer appearance-none bg-transparent
                  ${
                    selectedDirection === "toYanyuan"
                      ? "range-blue"
                      : "range-green"
                  }`}
                  style={{
                    WebkitAppearance: "none",
                    margin: 0,
                  }}
                />
              </div>
            </div>
            <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-1">
              <span>00:00</span>
              <span>12:00</span>
              <span>23:59</span>
            </div>
          </div>
        </div>

        <div>
          <button
            type="submit"
            className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 dark:focus:ring-blue-400 transition duration-150 ease-in-out transform hover:scale-105"
          >
            登录
          </button>
        </div>
      </form>
    </div>
  );
}
