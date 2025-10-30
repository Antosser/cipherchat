<script setup>
import { ref, computed, onMounted } from "vue";
import store from "../store.js";

// Reactive state
const newMessage = ref("");
const showImportDialog = ref(false);
const showStartChatDialog = ref(false);
const ownVerKey = ref(null);
const ownSignKey = ref(null);
const importKeyInput = ref("");
const startChatKeyInput = ref("");
const isKeyLoaded = ref(false);
const status = ref("Not connected");
const sidebarOpen = ref(false);

// Computed from store
const chats = computed(() => store.getChats());
const currentChat = computed(() => {
  const id = store.state.currentChatId;
  const found = store.getChats().find((c) => c.id === id);
  return found;
});
const messages = computed(() => store.getMessages());

// Convert byte array <-> MAC string
const bytesToMacString = (bytes) => {
  return bytes
    .map((b) => b.toString(16).padStart(2, "0"))
    .join(":")
    .toUpperCase();
};

const macStringToBytes = (mac) => {
  return mac
    .split(":")
    .map((s) => parseInt(s, 16))
    .filter((b) => !isNaN(b));
};

// Init on mount
onMounted(() => {
  isKeyLoaded.value = store.state.isKeyLoaded;
  if (isKeyLoaded.value) {
    ownSignKey.value = store.getCurrentSignKey();
    ownVerKey.value = store.getCurrentVerKey();
  }
});

// Switch chat
const switchChat = (chatId) => {
  store.setCurrentChat(chatId);
};

// Send message
const sendMessage = async () => {
  if (newMessage.value.trim() === "" || !isKeyLoaded.value) return;

  try {
    await store.sendMessage(newMessage.value.trim());
    newMessage.value = "";
  } catch (e) {
    console.error("Failed to send:", e);
  }
};

// Generate key
const generateKey = async () => {
  try {
    await store.generateKey();
    isKeyLoaded.value = true;
    ownSignKey.value = store.getCurrentSignKey();
    ownVerKey.value = store.getCurrentVerKey();
    status.value = "Key generated, connected.";
  } catch (e) {
    status.value = "Key generation failed";
    console.error(e);
  }
};

// Import key from MAC-style string
const confirmImportKey = async () => {
  try {
    const keyBytes = macStringToBytes(importKeyInput.value.trim());
    if (keyBytes.length === 0) throw new Error("Invalid format");

    await store.importKey(keyBytes);
    isKeyLoaded.value = true;
    ownVerKey.value = store.getCurrentVerKey();
    ownSignKey.value = store.getCurrentSignKey();
    status.value = "Key imported, connected.";
    showImportDialog.value = false;
  } catch (e) {
    status.value = "Key import failed";
    console.error(e);
  }
};

// Start new chat from MAC-style string
const confirmStartChat = async () => {
  try {
    const keyBytes = macStringToBytes(startChatKeyInput.value.trim());
    if (keyBytes.length === 0) throw new Error("Invalid format");

    await store.startChat(keyBytes);
    showStartChatDialog.value = false;
    startChatKeyInput.value = "";
  } catch (e) {
    console.error("Failed to start chat:", e);
  }
};
</script>

<template>
  <div class="chat-container">
    <!-- Sidebar -->
    <div class="sidebar" :class="{ show: sidebarOpen }">
      <div class="app-name">Secure Chat App</div>

      <button class="menu-toggle" @click="sidebarOpen = !sidebarOpen">☰</button>

      <div class="chat-list">
        <div
          v-for="chat in chats"
          :key="chat.id"
          class="chat-item"
          :class="{ active: currentChat?.id === chat.id }"
          @click="switchChat(chat.id)"
        >
          {{ chat.name }}
        </div>
      </div>

      <div class="crypto-controls">
        <button @click="generateKey">Generate Key</button>
        <button @click="showImportDialog = true">Import Key</button>
        <button @click="showStartChatDialog = true" :disabled="!isKeyLoaded">
          Start Chat
        </button>

        <div class="status">{{ status }}</div>

        <div v-if="isKeyLoaded && ownVerKey" class="verkey-display">
          <div>Your VerKey:</div>
          <div class="monospace">
            {{ bytesToMacString(ownVerKey) }}
          </div>
        </div>

        <div v-if="isKeyLoaded && ownSignKey" class="verkey-display">
          <div>Your SignKey:</div>
          <div class="monospace">
            {{ bytesToMacString(ownSignKey) }}
          </div>
        </div>
      </div>
    </div>

    <!-- Main Chat Area -->
    <div class="main-area">
      <div class="messages-container">
        <div
          v-for="message in messages"
          :key="message.id"
          class="message"
          :class="{
            sent: message.type === 'sent',
            received: message.type === 'received',
            system: message.type === 'system',
          }"
        >
          {{ message.text }}
        </div>
      </div>

      <div class="input-container">
        <input
          v-model="newMessage"
          @keyup.enter="sendMessage"
          :disabled="!isKeyLoaded || !currentChat"
          placeholder="Type a message..."
        />
        <button @click="sendMessage" :disabled="!isKeyLoaded || !currentChat">
          Send
        </button>
      </div>
    </div>

    <!-- Import Key Dialog -->
    <div v-if="showImportDialog" class="modal-overlay">
      <div class="modal">
        <h3>Import Your Sign Key</h3>
        <input v-model="importKeyInput" placeholder="AA:BB:CC:DD..." />
        <div class="modal-actions">
          <button @click="confirmImportKey">Import</button>
          <button @click="showImportDialog = false">Cancel</button>
        </div>
      </div>
    </div>

    <!-- Start Chat Dialog -->
    <div v-if="showStartChatDialog" class="modal-overlay">
      <div class="modal">
        <h3>Start New Chat</h3>
        <input v-model="startChatKeyInput" placeholder="AA:BB:CC:DD..." />
        <div class="modal-actions">
          <button @click="confirmStartChat">Start</button>
          <button @click="showStartChatDialog = false">Cancel</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Existing styles unchanged... */

.verkey-display {
  margin-top: 10px;
  font-size: 12px;
  color: #ccc;
  word-break: break-all;
}

.monospace {
  font-family: monospace;
  font-size: 13px;
  color: #10a37f;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
}

.modal {
  background: white;
  padding: 24px;
  border-radius: 12px;
  min-width: 300px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
}

.modal input {
  width: 100%;
  padding: 12px;
  margin: 12px 0;
  font-size: 14px;
  border: 1px solid #ccc;
  border-radius: 8px;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.modal-actions button {
  padding: 10px 16px;
  background-color: #10a37f;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
}

.modal-actions button:hover {
  background-color: #0d8c6c;
}

.chat-container {
  display: flex;
  width: 100%;
  height: 100vh;
  background-color: #f7f7f8;
}

.sidebar {
  width: 260px;
  background-color: #202123;
  color: white;
  display: flex;
  flex-direction: column;
}

.app-name {
  padding: 24px 16px;
  font-size: 18px;
  font-weight: 600;
  border-bottom: 1px solid #4d4d4f;
}

.identities-list {
  padding: 10px;
  overflow-y: auto;
  flex-grow: 1;
}

.identity-item {
  padding: 12px;
  border-radius: 6px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.identity-item:hover {
  background-color: #2b2c2f;
}

.identity-item.active {
  background-color: #343541;
  font-weight: 500;
}

.crypto-controls {
  padding: 16px;
  border-top: 1px solid #4d4d4f;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.crypto-controls button {
  padding: 10px 14px;
  background-color: #10a37f;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
}

.crypto-controls button:hover {
  background-color: #0d8c6c;
}

.crypto-controls .status {
  margin-top: 6px;
  font-size: 12px;
  color: #aaa;
}

.main-area {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.messages-container {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.message {
  max-width: 80%;
  padding: 16px 20px;
  border-radius: 8px;
  line-height: 1.5;
}

.message.sent {
  background-color: #e7f7ff;
  align-self: flex-end;
  border-bottom-right-radius: 0;
}

.message.received {
  background-color: #f1f1f1;
  align-self: flex-start;
  border-bottom-left-radius: 0;
}

.message.system {
  background-color: #f9f9f9;
  align-self: center;
  font-style: italic;
  color: #666;
  font-size: 0.9em;
  border: 1px solid #eee;
}

.input-container {
  padding: 16px 24px;
  border-top: 1px solid #e5e5e7;
  display: flex;
  gap: 12px;
}

.input-container input {
  flex: 1;
  padding: 14px 16px;
  border: 1px solid #e5e5e7;
  border-radius: 8px;
  font-size: 16px;
  outline: none;
  box-shadow: 0 0 10px rgba(0, 0, 0, 0.05);
}

.input-container input:focus {
  border-color: #10a37f;
}

.input-container button {
  padding: 14px 24px;
  background-color: #10a37f;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 500;
  transition: background-color 0.2s;
}

.input-container button:hover {
  background-color: #0d8c6c;
}

/* --- Mobile Responsiveness --- */
@media (max-width: 768px) {
  .chat-container {
    flex-direction: column;
    height: 100dvh; /* dynamic viewport height for phones */
  }

  .sidebar {
    width: 100%;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 12px;
    border-bottom: 1px solid #4d4d4f;
  }

  .app-name {
    padding: 0;
    font-size: 16px;
    border: none;
  }

  .chat-list {
    display: none; /* Hide sidebar chat list on small screens */
  }

  .crypto-controls {
    display: none; /* Hide crypto controls unless toggled */
  }

  .main-area {
    flex: 1;
    width: 100%;
  }

  .messages-container {
    padding: 16px;
    gap: 16px;
  }

  .input-container {
    padding: 12px;
    gap: 8px;
  }

  .input-container input {
    font-size: 15px;
  }
}

@media (max-width: 768px) {
  .sidebar {
    flex-direction: column;
    align-items: flex-start;
  }

  .menu-toggle {
    background: none;
    border: none;
    color: white;
    font-size: 24px;
    cursor: pointer;
    margin-left: auto;
  }

  .chat-list,
  .crypto-controls {
    display: none;
    width: 100%;
  }

  .sidebar.show .chat-list,
  .sidebar.show .crypto-controls {
    display: flex;
    flex-direction: column;
  }
}

html,
body {
  margin: 0;
  padding: 0;
  overflow: hidden;
}

.chat-container {
  overflow: hidden;
}

.messages-container {
  overflow-y: auto;
  word-wrap: break-word;
}

@media (max-width: 480px) {
  .modal {
    width: 90%;
    min-width: unset;
    padding: 16px;
  }

  .modal input {
    font-size: 13px;
    padding: 10px;
  }

  .crypto-controls button,
  .modal-actions button {
    font-size: 13px;
    padding: 8px 12px;
  }
}

.menu-toggle {
  display: none; /* hidden by default */
}

@media (max-width: 768px) {
  .menu-toggle {
    display: block; /* only show on smaller screens */
  }
}

@media (max-width: 768px) {
  .sidebar {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
  }

  .app-name {
    font-size: 16px;
    padding: 0;
  }

  .menu-toggle {
    background: none;
    border: none;
    color: white;
    font-size: 24px;
    cursor: pointer;
  }
}
</style>
