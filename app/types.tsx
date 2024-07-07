interface AuthError {
  message: string;
}

interface ReservationResult {
  is_to_yanyuan: boolean;
  qrcode_type: string;
  route_name: string;
  start_time: string;
  qrcode: string;
  app_id: string;
  app_appointment_id: string;
}

export type { AuthError, ReservationResult };
