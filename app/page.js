// page.js
import { ThemeProvider } from "next-themes";
import ReservationApp from "./components/ReservationApp";
import { checkLoginStatus } from "./actions";

export default async function Home() {
  const { user, reservationData } = await checkLoginStatus();

  return (
    <ThemeProvider attribute="class">
      <ReservationApp
        initialUser={user}
        initialReservationData={reservationData}
      />
    </ThemeProvider>
  );
}
