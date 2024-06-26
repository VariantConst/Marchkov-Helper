// app/actions.js
"use server";

import { cookies } from "next/headers";

async function getReservations(
  username,
  password,
  currentTime,
  criticalTime,
  direction
) {
  try {
    const isReturn = shouldReturnTrip(currentTime, criticalTime, direction);
    const response = await fetch("http://localhost:8000/get_qr_code", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        username: username,
        password: password,
        target_time: currentTime,
        is_return: isReturn,
      }),
    });

    if (!response.ok) {
      throw new Error("请求失败");
    }

    const data = await response.json();
    console.log("Reservation data:", data);
    return data;
  } catch (error) {
    console.error("获取预约信息时出错:", error);
    return {
      success: false,
      message: "获取预约信息失败，请稍后再试",
      reservations: [],
    };
  }
}

function shouldReturnTrip(currentTime, criticalTime, direction) {
  const today = new Date();
  const current = new Date(today.toDateString() + " " + currentTime);
  const critical = new Date(today.toDateString() + " " + criticalTime);

  if (direction === "toChangping") {
    return current <= critical;
  } else {
    return current > critical;
  }
}

export async function loginAction(formData) {
  const username = formData.get("username");
  const password = formData.get("password");
  const currentTime = formData.get("currentTime") || getCurrentBeijingTime();
  const criticalTime = formData.get("criticalTime");
  const direction = formData.get("direction");
  const cookieOptions = {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    maxAge: 60 * 60 * 24 * 30, // 30 days
    path: "/",
  };

  cookies().set("username", username, cookieOptions);
  cookies().set("password", password, cookieOptions);
  cookies().set("currentTime", currentTime, cookieOptions);
  cookies().set("criticalTime", criticalTime, cookieOptions);
  cookies().set("direction", direction, cookieOptions);

  const reservationData = await getReservations(
    username,
    password,
    currentTime,
    criticalTime,
    direction
  );

  console.log("Login action result:", {
    user: { username, currentTime, criticalTime, direction },
    reservationData,
  });

  return {
    user: { username, currentTime, criticalTime, direction },
    reservationData,
  };
}

export async function logoutAction() {
  cookies().delete("username", { path: "/" });
  cookies().delete("password", { path: "/" });
  cookies().delete("currentTime", { path: "/" });
  cookies().delete("criticalTime", { path: "/" });
  cookies().delete("direction", { path: "/" });
}

export async function checkLoginStatus() {
  const cookieStore = cookies();
  const username = cookieStore.get("username")?.value;
  const password = cookieStore.get("password")?.value;
  const currentTime = cookieStore.get("currentTime")?.value;
  const criticalTime = cookieStore.get("criticalTime")?.value;
  const direction = cookieStore.get("direction")?.value;

  if (username && password && currentTime && criticalTime && direction) {
    return {
      user: { username, currentTime, criticalTime, direction },
      reservationData: null,
    };
  }

  return {
    user: null,
    reservationData: null,
  };
}

export async function refreshReservationData() {
  const cookieStore = cookies();
  const username = cookieStore.get("username")?.value;
  const password = cookieStore.get("password")?.value;
  const currentTime = cookieStore.get("currentTime")?.value;
  const criticalTime = cookieStore.get("criticalTime")?.value;
  const direction = cookieStore.get("direction")?.value;

  if (username && password && currentTime && criticalTime && direction) {
    console.log("Refreshing reservation data for:", username);
    const reservationData = await getReservations(
      username,
      password,
      currentTime,
      criticalTime,
      direction
    );
    return reservationData;
  }
  console.log("Unable to refresh: missing user information");
  return { success: false, message: "未找到用户信息", reservations: [] };
}

function getCurrentBeijingTime() {
  const now = new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Shanghai" })
  );
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  return `${hours}:${minutes}`;
}
