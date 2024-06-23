// app/BusReservationManager.js
import BusReservationClient from "./BusReservationClient";

async function reserveBus(type) {
  const res = await fetch(`${process.env.BACKEND_URL}/reserve`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      type: type,
      time: "08:31", // 您可以根据需要修改这个时间
      headless: true,
    }),
  });

  if (!res.ok) {
    throw new Error(`Failed to reserve bus for ${type}`);
  }

  return await res.json();
}

async function getBusInfo(type) {
  const res = await fetch(`${process.env.BACKEND_URL}/qr-code/${type}`, {
    cache: "no-store",
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch bus info for ${type}`);
  }

  const contentDisposition = res.headers.get("content-disposition");
  let busTime = "";
  let tempCode = "";

  console.log(`contentDisposition: ${contentDisposition}`);
  if (contentDisposition) {
    const filenameMatch = contentDisposition.match(/filename\*=UTF-8''(.+)/);
    if (filenameMatch) {
      const filename = decodeURIComponent(filenameMatch[1]);
      const timeMatch = filename.match(/bus_(\d+)-save_(\d+)-(.+)\.png$/);
      if (timeMatch) {
        busTime = timeMatch[1];
        tempCode = timeMatch[3];
      }
    }
  }

  const arrayBuffer = await res.arrayBuffer();
  const base64 = Buffer.from(arrayBuffer).toString("base64");
  return {
    qrCode: contentDisposition ? `data:image/png;base64,${base64}` : null,
    busTime,
    tempCode,
  };
}

export default async function BusReservationManager() {
  try {
    // 预约回寝班车
    const 回寝Reservation = await reserveBus("回寝");
    let 回寝Info = { qrCode: null, busTime: "", tempCode: "" };
    if (回寝Reservation.success) {
      回寝Info = await getBusInfo("回寝");
    } else {
      console.error(`Failed to reserve 回寝 bus: ${回寝Reservation.message}`);
    }

    // 预约上班班车
    const 上班Reservation = await reserveBus("上班");
    let 上班Info = { qrCode: null, busTime: "", tempCode: "" };
    if (上班Reservation.success) {
      上班Info = await getBusInfo("上班");
    } else {
      console.error(`Failed to reserve 上班 bus: ${上班Reservation.message}`);
    }
    return (
      <BusReservationClient
        回寝QRCode={回寝Info.qrCode}
        回寝BusTime={回寝Info.busTime}
        回寝TempCode={回寝Info.tempCode}
        上班QRCode={上班Info.qrCode}
        上班BusTime={上班Info.busTime}
        上班TempCode={上班Info.tempCode}
      />
    );
  } catch (error) {
    console.error("Error in BusReservationManager:", error);
    return <div>Error: 获取班车信息时出错，请稍后重试。</div>;
  }
}
