import { useState, useEffect } from "react";
import { ChevronRightIcon, ClockIcon, MapPinIcon } from "lucide-react";

export default function LoginForm({ onSubmit }) {
  const [currentTime, setCurrentTime] = useState("");
  const [currentSliderValue, setCurrentSliderValue] = useState(0);
  const [criticalTime, setCriticalTime] = useState("14:00");
  const [criticalSliderValue, setCriticalSliderValue] = useState(840); // 14:00 in minutes
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
    // 移除自动更新时间的interval
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

  return (
    <div className="bg-white shadow-lg rounded-xl p-8 max-w-md mx-auto transition-all duration-300 ease-in-out transform hover:shadow-xl">
      <h2 className="text-3xl font-bold mb-8 text-center text-gray-800">
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
            className="block text-sm font-medium text-gray-700 mb-1 transition-colors duration-200 ease-in-out group-hover:text-blue-600"
          >
            用户名
          </label>
          <div className="relative">
            <input
              type="text"
              name="username"
              id="username"
              required
              className="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 ease-in-out"
            />
            <ChevronRightIcon className="absolute right-3 top-2.5 h-5 w-5 text-gray-400 transition-colors duration-200 ease-in-out group-hover:text-blue-600" />
          </div>
        </div>

        <div className="group">
          <label
            htmlFor="password"
            className="block text-sm font-medium text-gray-700 mb-1 transition-colors duration-200 ease-in-out group-hover:text-blue-600"
          >
            密码
          </label>
          <div className="relative">
            <input
              type="password"
              name="password"
              id="password"
              required
              className="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 ease-in-out"
            />
            <ChevronRightIcon className="absolute right-3 top-2.5 h-5 w-5 text-gray-400 transition-colors duration-200 ease-in-out group-hover:text-blue-600" />
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center">
              <ClockIcon className="mr-2 h-5 w-5 text-blue-500" />
              当前时间: {currentTime}
            </label>
            <input
              type="range"
              min="0"
              max="1439"
              value={currentSliderValue}
              onChange={handleCurrentSliderChange}
              className="w-full h-2 bg-blue-200 rounded-lg appearance-none cursor-pointer"
            />
            <div className="flex justify-between text-xs text-gray-500 mt-1">
              <span>00:00</span>
              <span>12:00</span>
              <span>23:59</span>
            </div>
          </div>

          <div>
            <label
              htmlFor="criticalTime"
              className="block text-sm font-medium text-gray-700 mb-2 flex items-center"
            >
              <ClockIcon className="mr-2 h-5 w-5 text-blue-500" />
              临界时间: {criticalTime}
            </label>
            <input
              type="range"
              min="0"
              max="1439"
              value={criticalSliderValue}
              onChange={handleCriticalSliderChange}
              className="w-full h-2 bg-blue-200 rounded-lg appearance-none cursor-pointer"
            />
            <div className="flex justify-between text-xs text-gray-500 mt-1">
              <span>00:00</span>
              <span>12:00</span>
              <span>23:59</span>
            </div>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center">
            <MapPinIcon className="mr-2 h-5 w-5 text-blue-500" />
            在临界时刻之前去：
          </label>
          <div className="grid grid-cols-2 gap-4">
            {["toChangping", "toYanyuan"].map((direction) => (
              <button
                key={direction}
                type="button"
                onClick={() => setSelectedDirection(direction)}
                className={`
                  py-2 px-4 rounded-md text-sm font-medium
                  transition-all duration-200 ease-in-out
                  ${
                    selectedDirection === direction
                      ? "bg-blue-600 text-white shadow-md transform scale-105"
                      : "bg-gray-100 text-gray-800 hover:bg-gray-200"
                  }
                `}
              >
                {direction === "toChangping" ? "去昌平" : "去燕园"}
              </button>
            ))}
          </div>
        </div>

        <div>
          <button
            type="submit"
            className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition duration-150 ease-in-out transform hover:scale-105"
          >
            登录
          </button>
        </div>
      </form>
    </div>
  );
}
