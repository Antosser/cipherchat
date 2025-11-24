import { reactive } from "vue";
import {
  proxy_connect,
  make_keypair,
  load_sign_key,
  read_packet,
  init_chat,
  send_message,
} from "frontend-wasm";

const WEBSOCKET_URL = "/ws";

const state = reactive({
  chats: [], // [{ id, name, messages: [] }]
  currentChatId: null,
  signKey: null,
  verKey: null,
  websocket: null,
  isKeyLoaded: false,
  isAuthenticated: false,
});

export default {
  state,

  getChats() {
    console.log("[store] getChats called");
    return this.state.chats;
  },

  getCurrentChat() {
    const current = this.state.chats.find(
      (c) => c.id === this.state.currentChatId
    );
    console.log("[store] getCurrentChat:", current);
    return current;
  },

  setCurrentChat(chatId) {
    console.log("[store] setCurrentChat:", chatId);
    this.state.currentChatId = String(chatId);
  },

  getCurrentVerKey() {
    console.log("[store] getCurrentVerKey:", this.state.verKey);
    return this.state.verKey;
  },

  getCurrentSignKey() {
    console.log("[store] getCurrentSignKey:", this.state.signKey);
    return this.state.signKey;
  },

  getMessages() {
    const currentChat = this.getCurrentChat();
    const msgs = currentChat?.messages || [];
    console.log("[store] getMessages:", msgs);
    return msgs;
  },

  async sendMessage(text) {
    console.log("[store] sendMessage:", text);
    if (!this.state.isKeyLoaded || !this.state.currentChatId) {
      alert("[store] Cannot send message: key not loaded or chat not selected");
      alert("Key not loaded or chat not selected.");
    }

    try {
      const result = await send_message(text, BigInt(this.state.currentChatId));
      console.log("[store] Message sent", result);
      if (this.state.websocket) {
        this.state.websocket.send(result);

        const currentChat = this.getCurrentChat();
        if (currentChat) {
          currentChat.messages.push({ text, type: "sent" });
        }
      } else {
        alert("[store] WebSocket not connected");
      }
    } catch (err) {
      alert("[store] Failed to send message:" + err);
    }
  },

  async generateKey() {
    console.log("[store] generateKey called");
    try {
      const result = await make_keypair();
      const priv = Array.from(result[0]);
      const pub = Array.from(result[1]);

      console.log("[store] Keypair generated:", { priv, pub });
      this._storeKeypair(priv, pub);
    } catch (err) {
      alert("[store] Failed to generate key: " + err);
    }
  },

  async importKey(signKeyBytes) {
    console.log("[store] importKey called with:", signKeyBytes);
    try {
      const result = await load_sign_key(signKeyBytes);
      const priv = Array.from(result[0]);
      const pub = Array.from(result[1]);

      console.log("[store] Key imported:", { priv, pub });
      this._storeKeypair(priv, pub);
    } catch (err) {
      alert("[store] Failed to import key:" + err);
    }
  },

  _storeKeypair(priv, pub) {
    console.log("[store] _storeKeypair:", { priv, pub });
    this.state.signKey = priv;
    this.state.verKey = pub;
    this.state.isKeyLoaded = true;

    this._connectWebSocket();
  },

  async startChat(serverVerKeyBytes) {
    console.log("[store] startChat with server key:", serverVerKeyBytes);
    try {
      const result = await init_chat(serverVerKeyBytes);
      const { message_updates, packet } = JSON.parse(result);

      console.log("[store] init_chat result:", { message_updates, packet });
      this._handleMessageUpdates(message_updates);

      console.warn(packet, this.state.websocket);

      if (packet && this.state.websocket) {
        console.log("[store] Sending initial packet via websocket");
        try {
          this.state.websocket.send(packet);
        } catch (err) {
          alert("[store] Failed to send initial packet:" + err);
        }
      }
    } catch (err) {
      alert("[store] Failed to start chat:" + err);
    }
  },

  _connectWebSocket() {
    console.log("[store] _connectWebSocket called");

    try {
      if (this.state.websocket) {
        console.log("[store] Closing existing websocket");
        this.state.websocket.close();
      }

      const ws = new WebSocket(WEBSOCKET_URL);
      this.state.websocket = ws;

      ws.onopen = () => {
        console.log("[ws] connected");
      };

      let isFirstMessage = true;

      ws.onmessage = (event) => {
        console.log("[ws] onmessage:", event.data);

        if (isFirstMessage) {
          isFirstMessage = false;
          try {
            const proxyResponse = proxy_connect(JSON.parse(event.data));
            console.log("[ws] proxy_connect response:", proxyResponse);
            ws.send(proxyResponse);
            this.state.isAuthenticated = true;
          } catch (e) {
            alert("[ws] Failed to authenticate:" + e);
          }
          return;
        }

        try {
          const result = read_packet(event.data);
          const { message_updates, packet } = JSON.parse(result);
          console.log("[ws] Packet parsed:", { message_updates, packet });

          this._handleMessageUpdates(message_updates);
          if (packet) {
            console.log("[ws] Sending next packet");
            ws.send(packet);
          }
        } catch (e) {
          alert("[ws] Failed to handle packet:" + e);
        }
      };

      ws.onerror = (e) => {
        alert("[ws] error:" + e);
      };

      ws.onclose = () => {
        console.log("[ws] closed");
        this.state.websocket = null;
        this.state.isAuthenticated = false;
      };
    } catch (err) {
      alert("[store] Failed to connect websocket:" + err);
    }
  },

  _handleMessageUpdates(updates) {
    console.log("[store] _handleMessageUpdates:", updates);
    for (const update of updates) {
      const chatId = update.chat_id;
      console.log(
        `[store] Processing message for chat ${chatId}:`,
        update.message
      );

      let chat = this.state.chats.find((c) => c.id === chatId);
      if (!chat) {
        console.log(`[store] Creating new chat ${chatId}`);
        chat = {
          id: chatId,
          name: `Chat ${Number(BigInt(chatId) % 10000n)}`,
          messages: [],
        };
        this.state.chats.push(chat);

        if (!this.state.currentChatId) {
          this.state.currentChatId = chatId;
          console.log(`[store] Auto-selected chat ${chatId}`);
        }
      }

      if (!chat.messages) {
        chat.messages = [];
      }

      const newMessage = this._convertMessageToDisplay(update.message, chatId);
      chat.messages.push(newMessage);
      console.log("[store] Message added to chat:", newMessage);
    }
  },

  _convertMessageToDisplay(message, chatId) {
    console.log("[store] _convertMessageToDisplay:", message);
    let text = "";
    let type = "system";

    if (typeof message === "string") {
      text = message;
    } else if (message.ToOther) {
      text = message.ToOther.content;
      type = "sent";
    } else if (message.ToSelf) {
      text = message.ToSelf.content;
      type = "received";
    } else if (message.System) {
      text = message.System;
      type = "system";
    }

    const displayMessage = {
      id: chatId,
      text,
      type,
      timestamp: new Date(),
    };

    console.log("[store] Converted message:", displayMessage);
    return displayMessage;
  },
};
