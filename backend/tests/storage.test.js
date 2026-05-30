const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

const tempDir = path.join(os.tmpdir(), "absensi-storage-test");
process.env.STORAGE_PROVIDER = "local";
process.env.LOCAL_STORAGE_DIR = tempDir;

const { persistAttendancePhoto, readLocalPhoto } = require("../src/modules/attendance/storage.service");
const { sha256 } = require("../src/utils/crypto");

test("local storage saves photo and verifies hash", async () => {
  await fs.rm(tempDir, { recursive: true, force: true });
  const bytes = Buffer.from("fake-jpeg-content");
  const result = await persistAttendancePhoto({
    photoBase64: bytes.toString("base64"),
    photoHash: sha256(bytes),
    userId: "user-1",
    sessionId: "session-1",
  });

  assert.equal(result.photoHash, sha256(bytes));
  assert.ok(result.photoUrl.startsWith("local://attendance/"));

  const saved = await readLocalPhoto(result.photoUrl.slice("local://".length));
  assert.deepEqual(saved, bytes);
});

test("local storage rejects mismatched hash", async () => {
  await assert.rejects(
    () =>
      persistAttendancePhoto({
        photoBase64: Buffer.from("fake-jpeg-content").toString("base64"),
        photoHash: "0".repeat(64),
        userId: "user-1",
        sessionId: "session-1",
      }),
    /Hash foto tidak cocok/,
  );
});

