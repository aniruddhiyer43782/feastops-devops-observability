FROM node:20-alpine AS dependencies

WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:20-alpine

LABEL org.opencontainers.image.title="FeastOps Mumbai Food Delivery API"
LABEL org.opencontainers.image.description="Mumbai food discovery and delivery tracking app with Prometheus metrics"
LABEL org.opencontainers.image.source="https://github.com/aniruddhiyer43782/feastops-devops-observability"

WORKDIR /usr/src/app
ENV NODE_ENV=production
ENV PORT=3000

COPY --from=dependencies /usr/src/app/node_modules ./node_modules
COPY src ./src
COPY public ./public
COPY package*.json ./

EXPOSE 3000

USER node

CMD ["node", "src/server.js"]
