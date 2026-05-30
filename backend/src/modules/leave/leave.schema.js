const { z } = require("zod");

const createLeaveSchema = z.object({
  body: z.object({
    type: z.enum([
      "SAKIT",
      "CUTI_TAHUNAN",
      "DINAS_LUAR",
      "IZIN_MENDESAK",
      "CUTI_MELAHIRKAN",
      "CUTI_MENIKAH",
    ]),
    dateFrom: z.string().datetime(),
    dateTo: z.string().datetime(),
    reason: z.string().min(5),
    documentUrl: z.string().min(1).optional(),
    replacementUserId: z.string().uuid().optional(),
  }),
});

const approvalSchema = z.object({
  params: z.object({
    id: z.string().uuid(),
  }),
  body: z.object({
    action: z.enum(["APPROVE", "REJECT"]),
    comment: z.string().optional(),
  }),
});

module.exports = {
  approvalSchema,
  createLeaveSchema,
};
