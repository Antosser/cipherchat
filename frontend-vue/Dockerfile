# ---- 1. WASM BUILD ----
FROM rust:latest AS wasm-build
WORKDIR /app

RUN cargo install wasm-pack

# Copy protocol + frontend-wasm
COPY protocol ./protocol
COPY frontend-wasm ./frontend-wasm

WORKDIR /app/frontend-wasm
RUN wasm-pack build --target web --release


# ---- 2. FRONTEND BUILD ----
FROM node:22 AS frontend-build
WORKDIR /app

# Copy Vue project
COPY frontend-vue ./frontend-vue

# Copy generated wasm pkg into the frontend tree
COPY --from=wasm-build /app/frontend-wasm/pkg ./frontend-wasm/pkg

WORKDIR /app/frontend-vue
RUN npm ci
RUN npm run build


# ---- 3. NGINX SERVE ----
FROM nginx:stable-alpine
WORKDIR /usr/share/nginx/html
COPY --from=frontend-build /app/frontend-vue/dist ./

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
