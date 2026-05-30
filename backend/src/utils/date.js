const dayjs = require("dayjs");
const utc = require("dayjs/plugin/utc");
const timezone = require("dayjs/plugin/timezone");

dayjs.extend(utc);
dayjs.extend(timezone);

const APP_TZ = process.env.APP_TIMEZONE || "Asia/Jakarta";

function nowJakarta() {
  return dayjs().tz(APP_TZ);
}

function startOfMonth(month) {
  return dayjs.tz(`${month}-01`, APP_TZ).startOf("month").toDate();
}

function endOfMonth(month) {
  return dayjs.tz(`${month}-01`, APP_TZ).endOf("month").toDate();
}

function businessDaysInclusive(from, to) {
  let cursor = dayjs(from).startOf("day");
  const end = dayjs(to).startOf("day");
  let days = 0;

  while (cursor.isBefore(end) || cursor.isSame(end)) {
    const day = cursor.day();
    if (day !== 0 && day !== 6) days += 1;
    cursor = cursor.add(1, "day");
  }

  return days;
}

module.exports = {
  APP_TZ,
  businessDaysInclusive,
  dayjs,
  endOfMonth,
  nowJakarta,
  startOfMonth,
};

