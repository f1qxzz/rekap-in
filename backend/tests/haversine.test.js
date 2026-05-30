const test = require("node:test");
const assert = require("node:assert/strict");
const { haversineDistanceMeters } = require("../src/utils/haversine");

test("haversine returns near-zero for same coordinate", () => {
  const distance = haversineDistanceMeters(
    { latitude: -6.2, longitude: 106.816666 },
    { latitude: -6.2, longitude: 106.816666 },
  );
  assert.equal(Math.round(distance), 0);
});

test("haversine calculates Jakarta coordinate distance", () => {
  const distance = haversineDistanceMeters(
    { latitude: -6.2, longitude: 106.816666 },
    { latitude: -6.201, longitude: 106.816666 },
  );
  assert.ok(distance > 100);
  assert.ok(distance < 120);
});

