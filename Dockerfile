FROM node:22-alpine 

WORKDIR /app

COPY src/package*.json ./

RUN npm install 

COPY src/ .

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

USER appuser

EXPOSE 3000

CMD ["node", "index.js"]
