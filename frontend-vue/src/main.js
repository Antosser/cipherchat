import { createApp } from "vue";
import "./style.css";
import App from "./App.vue";

import init, {
  proxy_connect,
  make_keypair,
  load_sign_key,
  init_chat,
  read_packet,
  send_message,
} from "wasm-crypto";

init().then(
  () => {
    console.log("wasm-crypto initialized");

    console.log(make_keypair());

    createApp(App).mount("#app");
  },
  (err) => {
    console.error(err);
  }
);
