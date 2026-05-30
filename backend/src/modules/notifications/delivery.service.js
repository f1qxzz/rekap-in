const nodemailer = require("nodemailer");
const env = require("../../config/env");

let transporter;

async function sendPush({ token, title, body, metadata }) {
  if (!token || !env.FCM_SERVER_KEY) {
    return { delivered: false, reason: "FCM token/server key belum tersedia" };
  }

  const response = await fetch(env.FCM_SEND_URL, {
    method: "POST",
    headers: {
      Authorization: `key=${env.FCM_SERVER_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      to: token,
      notification: { title, body },
      data: stringifyMetadata(metadata),
      priority: "high",
    }),
  });

  return {
    delivered: response.ok,
    status: response.status,
  };
}

async function sendEmail({ to, subject, text }) {
  if (!to || !env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASS) {
    return { delivered: false, reason: "SMTP belum dikonfigurasi" };
  }

  const info = await getTransporter().sendMail({
    from: env.SMTP_FROM,
    to,
    subject,
    text,
  });

  return {
    delivered: true,
    messageId: info.messageId,
  };
}

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_PORT === 465,
      auth: {
        user: env.SMTP_USER,
        pass: env.SMTP_PASS,
      },
    });
  }
  return transporter;
}

function stringifyMetadata(metadata = {}) {
  return Object.fromEntries(
    Object.entries(metadata).map(([key, value]) => [key, typeof value === "string" ? value : JSON.stringify(value)]),
  );
}

module.exports = {
  sendEmail,
  sendPush,
};

