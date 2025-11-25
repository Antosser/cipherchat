FROM node:18-alpine AS builder

RUN npm install -g html-minifier-terser

WORKDIR /build

COPY . .

RUN html-minifier-terser index.html \
    --collapse-whitespace \
    --remove-comments \
    --remove-optional-tags \
    --minify-css true \
    --minify-js true \
    -o index.min.html

FROM nginx:stable-alpine

COPY --from=builder /build/index.min.html /usr/share/nginx/html/index.html

EXPOSE 80

