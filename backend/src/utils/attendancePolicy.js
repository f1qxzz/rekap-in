const { dayjs } = require("./date");

function timeToMinutes(value) {
  const [hours, minutes] = value.split(":").map(Number);
  return hours * 60 + minutes;
}

function minutesSinceStartOfDay(date) {
  const value = dayjs(date);
  return value.hour() * 60 + value.minute();
}

function determineAttendanceStatus({ shift, timestamp }) {
  if (!shift) return "HADIR";
  if (shift.isFlexible) return "HADIR";

  const start = timeToMinutes(shift.startTime);
  const actual = minutesSinceStartOfDay(timestamp);
  const maxOnTime = start + shift.lateToleranceMinutes;

  return actual <= maxOnTime ? "HADIR" : "TERLAMBAT";
}

function calculateOvertimeMinutes({ shift, checkoutAt }) {
  if (!shift || shift.isFlexible) return 0;

  const end = timeToMinutes(shift.endTime);
  const actual = minutesSinceStartOfDay(checkoutAt);
  const adjustedEnd = end < timeToMinutes(shift.startTime) ? end + 24 * 60 : end;
  const adjustedActual = actual < timeToMinutes(shift.startTime) ? actual + 24 * 60 : actual;
  const overtime = adjustedActual - adjustedEnd;

  return overtime > 30 ? Math.min(overtime, 180) : 0;
}

function assertGpsPolicy({ accuracy, isMockLocation, platform }) {
  if (isMockLocation) {
    return {
      allowed: false,
      code: "MOCK_LOCATION",
      message: "Fake GPS terdeteksi. Absensi diblokir dan dicatat ke audit log.",
    };
  }

  if (Number(accuracy) > 50) {
    return {
      allowed: false,
      code: platform === "ios" && Number(accuracy) > 200 ? "IOS_LOW_CONFIDENCE_GPS" : "LOW_ACCURACY",
      message: "Akurasi GPS harus maksimal 50 meter sebelum absen.",
    };
  }

  return { allowed: true };
}

module.exports = {
  assertGpsPolicy,
  calculateOvertimeMinutes,
  determineAttendanceStatus,
  timeToMinutes,
};

