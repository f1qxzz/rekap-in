const clients = new Map();

function registerClient(id, client) {
  clients.set(id, client);
}

function removeClient(id) {
  clients.delete(id);
}

function broadcast(event, data, options = {}) {
  const payload = `data: ${JSON.stringify({ type: event, ...data })}\n\n`;
  for (const [clientId, client] of clients) {
    if (options.role && client.role !== options.role && client.role !== "SUPER_ADMIN") continue;
    if (options.userId && client.userId !== options.userId) continue;
    try {
      client.res.write(payload);
    } catch (_) {
      clients.delete(clientId);
    }
  }
}

module.exports = { registerClient, removeClient, broadcast };
