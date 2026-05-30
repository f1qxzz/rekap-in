const Redis = require("ioredis");
const env = require("../config/env");

let redis;

function getRedis() {
  if (!env.REDIS_URL) return null;
  if (!redis) {
    redis = new Redis(env.REDIS_URL, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
    });
  }
  return redis;
}

module.exports = { getRedis };

