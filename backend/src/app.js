const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const swaggerUi = require("swagger-ui-express");
const YAML = require("yamljs");
const path = require("node:path");
const fs = require("node:fs");
const apiRoutes = require("./routes");
const errorHandler = require("./middleware/errorHandler");
const sse = require("./lib/sse");

function createApp() {
  const app = express();
  const openApi = YAML.load(path.resolve(__dirname, "../docs/openapi.yaml"));

  app.use(helmet());
  app.use(cors({
    origin: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(",") : true,
    credentials: true,
  }));
  app.use(express.json({ limit: "10mb" }));
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan("combined"));

  const globalLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: { code: "RATE_LIMITED", message: "Terlalu banyak request. Coba lagi dalam beberapa menit." } },
  });
  app.use("/api", globalLimiter);

  const authLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: { code: "RATE_LIMITED", message: "Terlalu banyak percobaan. Coba lagi dalam beberapa menit." } },
  });
  app.use("/api/auth/login", authLimiter);
  app.use("/api/auth/register", authLimiter);
  app.use("/api/auth/password-reset/request", authLimiter);

  app.get("/health", (req, res) => {
    res.json({
      ok: true,
      service: "absensi-backend",
      timestamp: new Date().toISOString(),
    });
  });

  app.get("/config", (req, res) => {
    if (process.env.NODE_ENV === "production") {
      return res.status(404).json({ error: { code: "NOT_FOUND" } });
    }
    let tunnelUrl = null;
    try {
      const tunnelFile = path.resolve(__dirname, "../.tunnel-url");
      if (fs.existsSync(tunnelFile)) {
        tunnelUrl = fs.readFileSync(tunnelFile, "utf-8").trim();
      }
    } catch (_) {}
    res.json({
      service: "absensi-backend",
      tunnelUrl,
      timestamp: new Date().toISOString(),
    });
  });

  app.get("/api/events", (req, res) => {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });
    res.write("data: {\"type\":\"connected\"}\n\n");

    const clientId = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const role = req.query.role || "KARYAWAN";
    sse.registerClient(clientId, { res, role, userId: req.query.userId });

    req.on("close", () => {
      sse.removeClient(clientId);
    });
  });

  if (process.env.NODE_ENV !== "production") {
    app.use("/api/docs", swaggerUi.serve, swaggerUi.setup(openApi));
  }
  app.use("/api", apiRoutes);

  app.use((req, res) => {
    res.status(404).json({
      error: {
        code: "NOT_FOUND",
        message: "Endpoint tidak ditemukan",
      },
    });
  });

  app.use(errorHandler);

  return app;
}

module.exports = createApp;

