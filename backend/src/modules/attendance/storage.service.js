const fs = require("node:fs/promises");
const path = require("node:path");
const {
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const env = require("../../config/env");
const { badRequest } = require("../../utils/errors");
const { sha256 } = require("../../utils/crypto");

let s3Client;

async function persistAttendancePhoto({ photoBase64, photoUrl, photoHash, userId, sessionId }) {
  if (photoUrl && !photoBase64) {
    return { photoUrl, photoHash };
  }

  if (!photoBase64) {
    return { photoUrl: null, photoHash };
  }

  const bytes = Buffer.from(photoBase64, "base64");
  const computedHash = sha256(bytes);

  if (photoHash && photoHash.toLowerCase() !== computedHash) {
    throw badRequest("Hash foto tidak cocok dengan file yang diterima server");
  }

  const objectKey = buildObjectKey({ userId, sessionId, hash: computedHash });

  if (shouldUseS3()) {
    await uploadToS3(objectKey, bytes);
    return {
      photoUrl: `s3://${env.S3_BUCKET}/${objectKey}`,
      photoHash: computedHash,
    };
  }

  const filePath = path.resolve(env.LOCAL_STORAGE_DIR, objectKey);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, bytes);

  return {
    photoUrl: `local://${objectKey}`,
    photoHash: computedHash,
  };
}

async function signedPhotoUrl(photoUrl) {
  if (!photoUrl) return null;

  if (photoUrl.startsWith("s3://")) {
    const { bucket, key } = parseS3Url(photoUrl);
    return getSignedUrl(
      getS3Client(),
      new GetObjectCommand({ Bucket: bucket, Key: key }),
      { expiresIn: env.SIGNED_URL_TTL_SECONDS },
    );
  }

  if (photoUrl.startsWith("local://")) {
    return `/api/storage/photos/${photoUrl.slice("local://".length)}`;
  }

  return photoUrl;
}

async function readLocalPhoto(objectKey) {
  const safeKey = objectKey.replace(/\\/g, "/");
  if (safeKey.includes("..") || safeKey.startsWith("/")) {
    throw badRequest("Path foto tidak valid");
  }

  const filePath = path.resolve(env.LOCAL_STORAGE_DIR, safeKey);
  return fs.readFile(filePath);
}

async function persistDocument({ fileBase64, fileName, mimeType, userId }) {
  if (!fileBase64) throw badRequest("File dokumen wajib diisi");

  const bytes = Buffer.from(fileBase64, "base64");
  if (bytes.length > 5 * 1024 * 1024) {
    throw badRequest("Ukuran dokumen maksimal 5MB");
  }

  const safeName = sanitizeFileName(fileName || "dokumen");
  const hash = sha256(bytes);
  const date = new Date().toISOString().slice(0, 10);
  const key = `documents/${date}/${userId || "unknown-user"}/${hash.slice(0, 16)}-${safeName}`;

  if (shouldUseS3()) {
    await uploadToS3(key, bytes, mimeType || "application/octet-stream");
    return { documentUrl: `s3://${env.S3_BUCKET}/${key}`, sha256: hash };
  }

  const filePath = path.resolve(env.LOCAL_STORAGE_DIR, key);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, bytes);
  return { documentUrl: `local://${key}`, sha256: hash };
}

function buildObjectKey({ userId, sessionId, hash }) {
  const date = new Date().toISOString().slice(0, 10);
  const safeUser = userId || "unknown-user";
  const safeSession = sessionId || hash.slice(0, 16);
  return `attendance/${date}/${safeUser}/${safeSession}-${hash}.jpg`;
}

function shouldUseS3() {
  return env.STORAGE_PROVIDER === "s3" && env.S3_BUCKET && env.S3_ACCESS_KEY_ID && env.S3_SECRET_ACCESS_KEY;
}

async function uploadToS3(key, body, contentType = "image/jpeg") {
  await getS3Client().send(
    new PutObjectCommand({
      Bucket: env.S3_BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
      Metadata: {
        sha256: sha256(body),
      },
    }),
  );
}

function sanitizeFileName(value) {
  return value
    .replace(/\\/g, "-")
    .replace(/\//g, "-")
    .replace(/[^a-zA-Z0-9._-]/g, "-")
    .slice(0, 120);
}

function getS3Client() {
  if (!s3Client) {
    s3Client = new S3Client({
      region: env.S3_REGION,
      endpoint: env.S3_ENDPOINT || undefined,
      forcePathStyle: Boolean(env.S3_ENDPOINT),
      credentials: {
        accessKeyId: env.S3_ACCESS_KEY_ID,
        secretAccessKey: env.S3_SECRET_ACCESS_KEY,
      },
    });
  }
  return s3Client;
}

function parseS3Url(value) {
  const withoutScheme = value.slice("s3://".length);
  const slashIndex = withoutScheme.indexOf("/");
  return {
    bucket: withoutScheme.slice(0, slashIndex),
    key: withoutScheme.slice(slashIndex + 1),
  };
}

module.exports = {
  persistAttendancePhoto,
  persistDocument,
  readLocalPhoto,
  signedPhotoUrl,
};
