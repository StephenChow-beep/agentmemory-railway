FROM node:22-slim

ENV NODE_ENV=production
ENV HOME=/app
ENV PATH="/app/.local/bin:${PATH}"

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    bash \
    sed \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @agentmemory/agentmemory@0.9.12

RUN mkdir -p /app/.local/bin \
  && curl -fsSL "https://github.com/iii-hq/iii/releases/download/iii/v0.11.2/iii-x86_64-unknown-linux-gnu.tar.gz" \
  | tar -xz -C /app/.local/bin \
  && chmod +x /app/.local/bin/iii

RUN mkdir -p /data /app

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 8080
EXPOSE 3111
EXPOSE 3112
EXPOSE 3113
EXPOSE 49134

CMD ["/app/start.sh"]