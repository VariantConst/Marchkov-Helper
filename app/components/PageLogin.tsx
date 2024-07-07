import React from "react";

interface PageLoginProps {
  handleLogin: (event: React.FormEvent<HTMLFormElement>) => Promise<void>;
}

const PageLogin: React.FC<PageLoginProps> = ({ handleLogin }) => {
  return (
    <form onSubmit={handleLogin} className="space-y-4">
      <h1 className="text-2xl font-bold text-center text-indigo-800 dark:text-indigo-200">
        班车预约系统
      </h1>
      <input
        type="password"
        name="password"
        placeholder="请输入密码"
        className="w-full px-4 py-2 rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        required
      />
      <button
        type="submit"
        className="w-full px-4 py-2 text-white bg-indigo-600 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-opacity-50 dark:bg-blue-600 dark:hover:bg-blue-700"
      >
        登录
      </button>
    </form>
  );
};

export default PageLogin;
