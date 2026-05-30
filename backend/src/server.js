const createApp = require("./app");
const env = require("./config/env");
const { startScheduler } = require("./jobs/scheduler");
const prisma = require("./lib/prisma");

const app = createApp();

const server = app.listen(env.PORT, () => {
  console.log(`Absensi backend listening on http://localhost:${env.PORT}`);
  startScheduler();
});

function gracefulShutdown(signal) {
  console.log(`${signal} received. Starting graceful shutdown...`);
  server.close(async () => {
    console.log("HTTP server closed.");
    await prisma.$disconnect();
    console.log("Database connection closed.");
    process.exit(0);
  });

  setTimeout(() => {
    console.error("Forced shutdown after timeout.");
    process.exit(1);
  }, 10000);
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));
