FROM node:20-alpine AS dependencies

WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --omit=dev

FROM node:20-alpine

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
