const prisma = require("../lib/prisma");

async function writeAuditLog({ adminUserId, action, targetTable, targetId, beforeData, afterData, reason }) {
  await prisma.auditLog.create({
    data: {
      adminUserId: adminUserId || null,
      action,
      targetTable,
      targetId: targetId || null,
      beforeData: beforeData || undefined,
      afterData: afterData || undefined,
      reason: reason || null,
    },
  });
}

module.exports = { writeAuditLog };

