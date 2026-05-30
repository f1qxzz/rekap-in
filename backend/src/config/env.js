const dotenv = require("dotenv");
const { z } = require("zod");
const crypto = require("node:crypto");

dotenv.config();

const emptyToUndefined = (schema) =>
  z.preprocess((value) => (value === "" ? undefined : value), schema);

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(8080),
  API_BASE_URL: z.string().url().default("http://localhost:8080/api"),
  DATABASE_URL: z.string().min(1).optional(),
  REDIS_URL: z.string().optional(),
  JWT_PRIVATE_KEY: z.string().optional(),
  JWT_PUBLIC_KEY: z.string().optional(),
  ACCESS_TOKEN_TTL: z.string().default("15m"),
  REFRESH_TOKEN_DAYS: z.coerce.number().int().positive().default(7),
  APP_ENCRYPTION_KEY_BASE64: z.string().optional(),
  ATTENDANCE_RATE_LIMIT_PER_MINUTE: z.coerce.number().int().positive().default(10),
  OFFLINE_QUEUE_LIMIT: z.coerce.number().int().positive().default(5),
  PAYROLL_WEBHOOK_URL: emptyToUndefined(z.string().url().optional()),
  PAYROLL_WEBHOOK_SECRET: emptyToUndefined(z.string().optional()),
  SIGNED_URL_TTL_SECONDS: z.coerce.number().int().positive().default(3600),
  STORAGE_PROVIDER: z.enum(["local", "s3"]).default("local"),
  LOCAL_STORAGE_DIR: z.string().default("./storage/private"),
  S3_REGION: z.string().default("ap-southeast-1"),
  S3_BUCKET: emptyToUndefined(z.string().optional()),
  S3_ENDPOINT: emptyToUndefined(z.string().optional()),
  S3_ACCESS_KEY_ID: emptyToUndefined(z.string().optional()),
  S3_SECRET_ACCESS_KEY: emptyToUndefined(z.string().optional()),
  FCM_SERVER_KEY: emptyToUndefined(z.string().optional()),
  FCM_SEND_URL: z.string().url().default("https://fcm.googleapis.com/fcm/send"),
  SMTP_HOST: emptyToUndefined(z.string().optional()),
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_USER: emptyToUndefined(z.string().optional()),
  SMTP_PASS: emptyToUndefined(z.string().optional()),
  SMTP_FROM: z.string().default("Absensi <no-reply@example.com>"),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error(parsed.error.flatten().fieldErrors);
  throw new Error("Konfigurasi environment tidak valid");
}

const env = parsed.data;

function normalizePem(value) {
  if (!value || value.includes("CHANGE_ME")) return undefined;
  return value.replace(/\\n/g, "\n");
}

function generateDevJwtSecret() {
  return crypto.randomBytes(64).toString("hex");
}

const devJwtSecret = generateDevJwtSecret();
console.warn("[SECURITY] JWT_PRIVATE_KEY tidak diset. Menggunakan ephemeral key (berubah setiap restart).");

module.exports = {
  ...env,
  JWT_PRIVATE_KEY: normalizePem(env.JWT_PRIVATE_KEY),
  JWT_PUBLIC_KEY: normalizePem(env.JWT_PUBLIC_KEY),
  DEV_JWT_SECRET: devJwtSecret,
  isProduction: env.NODE_ENV === "production",
};
