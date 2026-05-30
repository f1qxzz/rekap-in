const prisma = require("../../lib/prisma");
const { notFound } = require("../../utils/errors");
const { sendEmail, sendPush } = require("./delivery.service");
const { broadcast: broadcastSSE } = require("../../lib/sse");

async function listMine(userId) {
  return prisma.notification.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
    take: 100,
  });
}

async function markRead(userId, id) {
  const notification = await prisma.notification.findFirst({
    where: { id, userId },
  });
  if (!notification) throw notFound("Notifikasi tidak ditemukan");

  return prisma.notification.update({
    where: { id },
    data: { read: true },
  });
}

async function markAllRead(userId) {
  const result = await prisma.notification.updateMany({
    where: { userId, read: false },
    data: { read: true },
  });
  return { updated: result.count };
}

async function createNotification({ userId, type, title, body, metadata }) {
  if (!userId) return null;

  const notification = await prisma.notification.create({
    data: {
      userId,
      type,
      title,
      body,
      metadata: metadata || undefined,
    },
  });

  await deliverNotification(notification).catch((error) => {
    console.error("Notification delivery failed", error.message);
  });

  broadcastSSE("notification:new", {
    notificationId: notification.id,
    type: notification.type,
    title: notification.title,
    body: notification.body,
  }, { userId });

  return notification;
}

async function notifyManagersAndAdmins({ type, title, body, metadata }) {
  const users = await prisma.user.findMany({
    where: {
      role: { in: ["MANAJER", "HR", "SUPER_ADMIN"] },
      isActive: true,
    },
    select: { id: true },
  });

  await Promise.all(
    users.map((user) =>
      createNotification({
        userId: user.id,
        type,
        title,
        body,
        metadata,
      }),
    ),
  );
}

module.exports = {
  createNotification,
  listMine,
  markAllRead,
  markRead,
  notifyManagersAndAdmins,
};

async function deliverNotification(notification) {
  const user = await prisma.user.findUnique({
    where: { id: notification.userId },
    select: { email: true, fcmToken: true },
  });
  if (!user) return;

  await Promise.all([
    sendPush({
      token: user.fcmToken,
      title: notification.title,
      body: notification.body,
      metadata: notification.metadata,
    }),
    shouldEmail(notification.type)
      ? sendEmail({
          to: user.email,
          subject: notification.title,
          text: notification.body,
        })
      : Promise.resolve({ delivered: false }),
  ]);
}

function shouldEmail(type) {
  return ["LEAVE_REQUEST", "LEAVE_REJECTED", "LEAVE_APPROVED", "ACCOUNT_APPROVAL"].includes(type);
}
