FROM node:22-slim

ENV NODE_ENV=production
ENV HOME=/app
ENV PATH="/app/.local/bin:${PATH}"

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl tar \
  && rm -rf /var/lib/apt/lists/*

# Installer agentmemory depuis npm
RUN npm install -g @agentmemory/agentmemory@0.9.12

# Installer iii-engine v0.11.2, version actuellement attendue par agentmemory
RUN mkdir -p /app/.local/bin \
  && curl -fsSL "https://github.com/iii-hq/iii/releases/download/iii/v0.11.2/iii-x86_64-unknown-linux-gnu.tar.gz" \
  | tar -xz -C /app/.local/bin \
  && chmod +x /app/.local/bin/iii

# Dossier persistant Railway
RUN mkdir -p /data

EXPOSE 3111
EXPOSE 3113

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]