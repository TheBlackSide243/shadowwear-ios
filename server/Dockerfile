# ShadowWear server: plain Node, no dependencies. The data (closet, photos, account) live in /data.
FROM node:22-alpine

LABEL org.opencontainers.image.title="ShadowWear server" \
      org.opencontainers.image.description="The ShadowWear closet on your own server: sync for the iPhone app and a web site for the computer." \
      org.opencontainers.image.source="https://github.com/TheBlackSide243/shadowwear-ios"

# su-exec: the entrypoint hands the data folder to the "node" user and runs the server as that user.
RUN apk add --no-cache su-exec

ENV PORT=8080 DATA_DIR=/data
WORKDIR /app
COPY package.json ./
COPY src ./src
COPY web ./web
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh && mkdir -p /data && chown node:node /data

VOLUME /data
EXPOSE 8080
HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD wget -qO- "http://127.0.0.1:${PORT}/api/status" >/dev/null || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "src/server.js"]
