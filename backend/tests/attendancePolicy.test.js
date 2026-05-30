const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertGpsPolicy,
  calculateOvertimeMinutes,
  determineAttendanceStatus,
} = require("../src/utils/attendancePolicy");

const shift = {
  startTime: "08:00",
  endTime: "17:00",
  lateToleranceMinutes: 10,
  isFlexible: false,
};

test("GPS policy blocks mock location", () => {
  const result = assertGpsPolicy({ accuracy: 10, isMockLocation: true, platform: "android" });
  assert.equal(result.allowed, false);
  assert.equal(result.code, "MOCK_LOCATION");
});

test("GPS policy blocks low accuracy", () => {
  const result = assertGpsPolicy({ accuracy: 51, isMockLocation: false, platform: "android" });
  assert.equal(result.allowed, false);
  assert.equal(result.code, "LOW_ACCURACY");
});

test("attendance status respects late tolerance", () => {
  assert.equal(determineAttendanceStatus({ shift, timestamp: "2026-05-28T08:10:00" }), "HADIR");
  assert.equal(determineAttendanceStatus({ shift, timestamp: "2026-05-28T08:11:00" }), "TERLAMBAT");
});

test("overtime starts after 30 minutes and caps at 180 minutes", () => {
  assert.equal(calculateOvertimeMinutes({ shift, checkoutAt: "2026-05-28T17:30:00" }), 0);
  assert.equal(calculateOvertimeMinutes({ shift, checkoutAt: "2026-05-28T18:00:00" }), 60);
  assert.equal(calculateOvertimeMinutes({ shift, checkoutAt: "2026-05-28T23:00:00" }), 180);
});
