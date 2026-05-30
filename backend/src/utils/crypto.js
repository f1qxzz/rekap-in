const crypto = require("node:crypto");
const env = require("../config/env");

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function randomToken(bytes = 32) {
  return crypto.randomBytes(bytes).toString("base64url");
}

function getEncryptionKey() {
  if (!env.APP_ENCRYPTION_KEY_BASE64 || env.APP_ENCRYPTION_KEY_BASE64.includes("CHANGE_ME")) {
    if (env.isProduction) {
      throw new Error("APP_ENCRYPTION_KEY_BASE64 wajib di-set di production");
    }
    return crypto.createHash("sha256").update("dev-only-attendance-key").digest();
  }

  const key = Buffer.from(env.APP_ENCRYPTION_KEY_BASE64, "base64");
  if (key.length !== 32) {
    throw new Error("APP_ENCRYPTION_KEY_BASE64 harus 32 bytes base64");
  }
  return key;
}

function encryptJson(payload) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", getEncryptionKey(), iv);
  const json = JSON.stringify(payload);
  const encrypted = Buffer.concat([cipher.update(json, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]).toString("base64url");
}

function decryptJson(value) {
  const raw = Buffer.from(value, "base64url");
  const iv = raw.subarray(0, 12);
  const tag = raw.subarray(12, 28);
  const encrypted = raw.subarray(28);
  const decipher = crypto.createDecipheriv("aes-256-gcm", getEncryptionKey(), iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
  return JSON.parse(decrypted.toString("utf8"));
}

function encryptText(value) {
  if (value === undefined || value === null || value === "") return null;
  return encryptJson({ value: String(value) });
}

module.exports = {
  decryptJson,
  encryptJson,
  encryptText,
  randomToken,
  sha256,
};

