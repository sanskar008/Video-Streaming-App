const WebSocket = require("ws");
const wss = new WebSocket.Server({ port: 8080 });

const streams = new Map(); // Map streamNumber to clients

wss.on("connection", (ws) => {
  console.log("A client connected");

  ws.send(JSON.stringify({ message: "Welcome to the WebRTC Server!" }));

  ws.on("message", (message) => {
    try {
      const data = JSON.parse(message);
      console.log("Received:", data);
      const streamNumber = data.streamNumber;

      if (data.type === "createStream") {
        // Generate unique stream number
        const newStreamNumber = Date.now().toString();
        streams.set(newStreamNumber, new Set([ws]));
        ws.send(
          JSON.stringify({
            type: "streamCreated",
            streamNumber: newStreamNumber,
          })
        );
      } else if (data.type === "join") {
        if (streams.has(streamNumber)) {
          streams.get(streamNumber).add(ws);
          ws.send(JSON.stringify({ message: `Joined stream ${streamNumber}` }));
        } else {
          ws.send(
            JSON.stringify({ type: "error", message: "Stream not found" })
          );
        }
      } else if (["offer", "answer", "candidate"].includes(data.type)) {
        if (streamNumber && streams.has(streamNumber)) {
          streams.get(streamNumber).forEach((client) => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(data));
            }
          });
        } else {
          ws.send(
            JSON.stringify({ type: "error", message: "Invalid stream number" })
          );
        }
      }
    } catch (e) {
      console.error("Error processing message:", e);
      ws.send(
        JSON.stringify({ type: "error", message: "Invalid message format" })
      );
    }
  });

  ws.on("close", () => {
    console.log("A client disconnected");
    streams.forEach((clients, streamNumber) => {
      clients.delete(ws);
      if (clients.size === 0) {
        streams.delete(streamNumber);
      }
    });
  });
});

console.log("WebSocket server running on ws://localhost:8080");
