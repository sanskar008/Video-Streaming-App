const WebSocket = require("ws");
const wss = new WebSocket.Server({ port: 8080 });

wss.on("connection", (ws) => {
  console.log("A client connected");

  // Send a message when a new connection is made
  ws.send(JSON.stringify({ message: "Welcome to the WebRTC Server!" }));

  ws.on("message", (message) => {
    console.log("received: %s", message);
    // Broadcast the message to all other clients (signaling)
    wss.clients.forEach((client) => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  });

  ws.on("close", () => {
    console.log("A client disconnected");
  });
});
