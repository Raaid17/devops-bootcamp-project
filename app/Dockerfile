# --- build stage ---
FROM node:24-alpine AS build
WORKDIR /app
# Manifests first so the install layer stays cached until deps actually change.
COPY package*.json ./
RUN npm ci
# Source after, so editing it does not bust the install cache above.
COPY . .
RUN npm run build

# --- runtime stage ---
# Only dist/ crosses over: no node_modules, no toolchain in the shipped image.
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
CMD ["nginx", "-g", "daemon off;"]
