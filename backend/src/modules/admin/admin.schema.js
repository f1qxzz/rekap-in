const { z } = require("zod");

const uuidParam = z.object({
  params: z.object({
    id: z.string().uuid(),
  }),
});

const createShiftSchema = z.object({
  body: z.object({
    name: z.string().min(2),
    startTime: z.string().regex(/^\d{2}:\d{2}$/),
    endTime: z.string().regex(/^\d{2}:\d{2}$/),
    workDays: z.array(z.number().int().min(0).max(6)).min(1),
    lateToleranceMinutes: z.number().int().min(0).max(120).default(10),
    isFlexible: z.boolean().default(false),
    flexibleHours: z.number().int().min(1).max(24).optional(),
  }),
});

const updateShiftSchema = uuidParam.extend({
  body: createShiftSchema.shape.body.partial().refine(
    (value) => Object.keys(value).length > 0,
    "Minimal satu field harus diisi",
  ),
});

const createOfficeSchema = z.object({
  body: z.object({
    name: z.string().min(2),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    radiusMeters: z.number().int().min(10).max(10000).default(100),
    isActive: z.boolean().optional(),
  }),
});

const updateOfficeSchema = uuidParam.extend({
  body: createOfficeSchema.shape.body.partial().refine(
    (value) => Object.keys(value).length > 0,
    "Minimal satu field harus diisi",
  ),
});

const createUserSchema = z.object({
  body: z.object({
    name: z.string().min(2),
    email: z.string().email(),
    nip: z.string().min(3),
    phone: z.string().optional(),
    password: z.string().min(8),
    departmentId: z.string().uuid().optional(),
    shiftId: z.string().uuid().optional(),
    directManagerId: z.string().uuid().optional(),
    officeLocationIds: z.array(z.string().uuid()).optional(),
    role: z.enum(["KARYAWAN", "MANAJER", "HR", "SUPER_ADMIN"]).default("KARYAWAN"),
  }),
});

const updateUserSchema = uuidParam.extend({
  body: z.object({
    name: z.string().min(2).optional(),
    phone: z.string().optional(),
    departmentId: z.string().uuid().nullable().optional(),
    shiftId: z.string().uuid().nullable().optional(),
    directManagerId: z.string().uuid().nullable().optional(),
    isActive: z.boolean().optional(),
    officeLocationIds: z.array(z.string().uuid()).optional(),
  }),
});

const updateRoleSchema = uuidParam.extend({
  body: z.object({
    role: z.enum(["KARYAWAN", "MANAJER", "HR", "SUPER_ADMIN"]),
    reason: z.string().min(3),
  }),
});

const approveUserSchema = uuidParam.extend({
  body: z.object({
    approved: z.boolean(),
    reason: z.string().optional(),
  }),
});

const reviewAnomalySchema = uuidParam.extend({
  body: z.object({
    action: z.enum(["APPROVE", "REJECT", "WARN"]),
    notes: z.string().min(3),
  }),
});

const importUsersSchema = z.object({
  body: z.object({
    users: z.array(createUserSchema.shape.body).min(1).max(500),
  }),
});

const createDepartmentSchema = z.object({
  body: z.object({
    name: z.string().min(2),
  }),
});

const updateDepartmentSchema = uuidParam.extend({
  body: createDepartmentSchema.shape.body,
});

const createHolidaySchema = z.object({
  body: z.object({
    name: z.string().min(2),
    date: z.string().datetime(),
    isCustom: z.boolean().default(true),
  }),
});

const updateHolidaySchema = uuidParam.extend({
  body: createHolidaySchema.shape.body.partial().refine(
    (value) => Object.keys(value).length > 0,
    "Minimal satu field harus diisi",
  ),
});

const listLeaveBalancesSchema = z.object({
  query: z.object({
    year: z.coerce.number().int().min(2000).max(2100).optional(),
    userId: z.string().uuid().optional(),
  }),
});

const createLeaveBalanceSchema = z.object({
  body: z.object({
    userId: z.string().uuid(),
    year: z.number().int().min(2000).max(2100),
    annualQuota: z.number().int().min(0).max(365).default(12),
    used: z.number().int().min(0).max(365).default(0),
  }),
});

const updateLeaveBalanceSchema = uuidParam.extend({
  body: z
    .object({
      annualQuota: z.number().int().min(0).max(365).optional(),
      used: z.number().int().min(0).max(365).optional(),
    })
    .refine((value) => Object.keys(value).length > 0, "Minimal satu field harus diisi"),
});

module.exports = {
  approveUserSchema,
  createDepartmentSchema,
  createHolidaySchema,
  createLeaveBalanceSchema,
  createOfficeSchema,
  createShiftSchema,
  createUserSchema,
  importUsersSchema,
  listLeaveBalancesSchema,
  reviewAnomalySchema,
  updateRoleSchema,
  updateDepartmentSchema,
  updateHolidaySchema,
  updateLeaveBalanceSchema,
  updateOfficeSchema,
  updateShiftSchema,
  updateUserSchema,
  uuidParam,
};
