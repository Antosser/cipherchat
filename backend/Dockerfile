# ---- Backend build stage ----
FROM rust:latest AS backend-build
WORKDIR /app

COPY protocol ./protocol
COPY backend ./backend

WORKDIR /app/backend
RUN cargo build --release

# ---- Runtime stage ----
FROM debian:bookworm-slim
WORKDIR /app
COPY --from=backend-build /app/backend/target/release/backend /app/backend

EXPOSE 8080
CMD ["./backend"]
