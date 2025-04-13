const WebSocket = require("ws");
const wss = new WebSocket.Server({ port: 8080 });

const streams = new Map();

wss.on("connection", (ws) => {
  console.log("Client connected");

  ws.on("message", (message) => {
    const data = JSON.parse(message);
    if (
      data.type === "offer" ||
      data.type === "answer" ||
      data.type === "candidate"
    ) {
      wss.clients.forEach((client) => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify(data));
        }
      });
    } else if (data.type === "join") {
      // Handle stream joining logic here
    }
  });

  ws.on("close", () => console.log("Client disconnected"));
});

console.log("WebSocket server running on ws://localhost:8080");
