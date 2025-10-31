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
    alert("Failed to send:", e);
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
    alert(e);
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
    alert(e);
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
    alert("Failed to start chat:", e);
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
