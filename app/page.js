// app/page.js
import ReservationApp from "./components/ReservationApp";
import { checkLoginStatus } from "./actions";

export default async function Home() {
  const { user, reservationData } = await checkLoginStatus();

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold text-gray-900">班车预约系统</h1>
        </div>
      </header>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <ReservationApp
            initialUser={user}
            initialReservationData={reservationData}
          />
        </div>
      </main>
    </div>
  );
}
