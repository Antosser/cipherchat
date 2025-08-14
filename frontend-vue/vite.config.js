import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import wasmPack from "vite-plugin-wasm-pack";

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), wasmPack("../wasm-crypto")],
});
