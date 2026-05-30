const { z } = require("zod");

const attendancePayload = z.object({
  type: z.enum(["MASUK", "PULANG", "LEMBUR"]),
  timestamp: z.string().datetime(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().positive(),
  provider: z.string().optional(),
  gpsTimestamp: z.string().datetime().optional(),
  photoUrl: z.string().min(1).optional(),
  photoBase64: z.string().min(20).optional(),
  photoHash: z.string().regex(/^[a-f0-9]{64}$/i).optional(),
  faceMatchScore: z.number().min(0).max(1).optional(),
  faceDetected: z.boolean().default(false),
  deviceId: z.string().min(3).optional(),
  platform: z.enum(["android", "ios"]).optional(),
  isMockLocationDetected: z.boolean().default(false),
  deviceIntegrity: z
    .object({
      verdict: z.enum(["UNKNOWN", "PASSED", "FAILED"]).default("UNKNOWN"),
      reason: z.string().optional(),
      isEmulator: z.boolean().optional(),
      isJailbrokenOrRooted: z.boolean().optional(),
      elapsedRealtimeMs: z.number().optional(),
      timezoneOffsetMinutes: z.number().optional(),
    })
    .optional(),
  sessionId: z.string().uuid().optional(),
  notes: z.string().max(500).optional(),
});

const clockSchema = z.object({
  body: attendancePayload.refine((value) => value.photoUrl || value.photoBase64, {
    message: "photoUrl atau photoBase64 wajib diisi",
    path: ["photoUrl"],
  }),
});

const offlineSyncSchema = z.object({
  body: z.object({
    entries: z.array(attendancePayload).min(1).max(5),
  }),
});

const historySchema = z.object({
  query: z.object({
    month: z.string().regex(/^\d{4}-\d{2}$/).optional(),
    status: z.string().optional(),
  }),
});

module.exports = {
  clockSchema,
  historySchema,
  offlineSyncSchema,
};
