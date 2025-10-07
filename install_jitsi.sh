#!/usr/bin/env bash
# Авторазвёртывание Jitsi Meet в Docker на Ubuntu 22.04+
set -euo pipefail

### === НАСТРОЙКИ ===
DOMAIN="meet.example.com"          # ← твой домен
EMAIL="admin@example.com"          # ← email для Let's Encrypt
TZ="UTC"                           # ← часовой пояс, напр. "Asia/Ho_Chi_Minh"
STACK_DIR="/opt/jitsi"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

### === ПРОВЕРКИ ===
if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root: sudo bash $0"
  exit 1
fi

command -v curl >/dev/null || apt-get update -y
apt-get install -y curl

echo "[1/8] Проверяю DNS домена → должен указывать на этот сервер…"
PUB_IP="$(curl -fsSL https://api.ipify.org || true)"
DNS_IP="$(getent ahosts "$DOMAIN" | awk 'NR==1{print $1}' || true)"
echo "Публичный IP: ${PUB_IP:-unknown}; DNS(${DOMAIN}): ${DNS_IP:-unknown}"
if [[ -n "${PUB_IP}" && -n "${DNS_IP}" && "${PUB_IP}" != "${DNS_IP}" ]]; then
  echo "⚠️  ВНИМАНИЕ: ${DOMAIN} сейчас не указывает на ${PUB_IP}. Let's Encrypt может не сработать."
fi

echo "[2/8] Устанавливаю Docker Engine + compose-plugin…"
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  echo "Docker уже установлен."
fi

echo "[3/8] Готовлю каталог стека: ${STACK_DIR}"
mkdir -p "${STACK_DIR}/config" "${STACK_DIR}/transcripts" "${STACK_DIR}/recordings"
cd "${STACK_DIR}"

echo "[4/8] Генерирую .env с безопасными паролями…"
# функции генерации
rand() { openssl rand -hex 16; }
cat > .env <<EOF
# === БАЗА ===
HTTP_PORT=80
HTTPS_PORT=443
TZ=${TZ}
PUBLIC_URL=https://${DOMAIN}
# включаем LE
ENABLE_LETSENCRYPT=1
LETSENCRYPT_DOMAIN=${DOMAIN}
LETSENCRYPT_EMAIL=${EMAIL}

# === ПАРОЛИ (автогенерация) ===
# Prosody (XMPP)
XMPP_DOMAIN=meet.jitsi
XMPP_SERVER=prosody
XMPP_AUTH_DOMAIN=auth.meet.jitsi
XMPP_MUC_DOMAIN=muc.meet.jitsi
XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
XMPP_GUEST_DOMAIN=guest.meet.jitsi
JICOFO_COMPONENT_SECRET=$(rand)
JICOFO_AUTH_PASSWORD=$(rand)
JVB_AUTH_PASSWORD=$(rand)

# Включаем гостевой доступ (опционально)
ENABLE_GUESTS=1

# TURN не настраиваем (по умолчанию WebRTC через UDP:10000)
# При необходимости доконфигурируй coturn отдельно.
EOF

echo "[5/8] Создаю docker-compose.yml…"
cat > "${COMPOSE_FILE}" <<'YML'
services:
  # XMPP сервер (Prosody)
  prosody:
    image: docker.io/jitsi/prosody:stable
    restart: unless-stopped
    networks:
      meet.jitsi:
        aliases:
          - prosody
    volumes:
      - ./config/prosody:/config:Z
    environment:
      - XMPP_DOMAIN=${XMPP_DOMAIN}
      - XMPP_AUTH_DOMAIN=${XMPP_AUTH_DOMAIN}
      - XMPP_MUC_DOMAIN=${XMPP_MUC_DOMAIN}
      - XMPP_INTERNAL_MUC_DOMAIN=${XMPP_INTERNAL_MUC_DOMAIN}
      - XMPP_GUEST_DOMAIN=${XMPP_GUEST_DOMAIN}
      - PUBLIC_URL=${PUBLIC_URL}
      - JICOFO_COMPONENT_SECRET=${JICOFO_COMPONENT_SECRET}
      - JICOFO_AUTH_PASSWORD=${JICOFO_AUTH_PASSWORD}
      - JVB_AUTH_PASSWORD=${JVB_AUTH_PASSWORD}
      - ENABLE_GUESTS=${ENABLE_GUESTS}
      - TZ=${TZ}

  # Веб-интерфейс (nginx) + Let's Encrypt
  web:
    image: docker.io/jitsi/web:stable
    restart: unless-stopped
    depends_on:
      - prosody
    networks:
      - meet.jitsi
    ports:
      - "${HTTP_PORT:-80}:80"
      - "${HTTPS_PORT:-443}:443"
    volumes:
      - ./config/web:/config:Z
      - ./transcripts:/usr/share/jitsi-meet/transcripts:Z
      - ./recordings:/recordings:Z
    environment:
      - PUBLIC_URL=${PUBLIC_URL}
      - ENABLE_LETSENCRYPT=${ENABLE_LETSENCRYPT}
      - LETSENCRYPT_DOMAIN=${LETSENCRYPT_DOMAIN}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
      - TZ=${TZ}

  # Jicofo (фокус конференций)
  jicofo:
    image: docker.io/jitsi/jicofo:stable
    restart: unless-stopped
    depends_on:
      - prosody
    networks:
      - meet.jitsi
    volumes:
      - ./config/jicofo:/config:Z
    environment:
      - XMPP_DOMAIN=${XMPP_DOMAIN}
      - XMPP_AUTH_DOMAIN=${XMPP_AUTH_DOMAIN}
      - XMPP_SERVER=prosody
      - JICOFO_COMPONENT_SECRET=${JICOFO_COMPONENT_SECRET}
      - JICOFO_AUTH_PASSWORD=${JICOFO_AUTH_PASSWORD}
      - TZ=${TZ}

  # Видео-бридж (медиа через UDP:10000)
  jvb:
    image: docker.io/jitsi/jvb:stable
    restart: unless-stopped
    networks:
      - meet.jitsi
    ports:
      - "10000:10000/udp"
    volumes:
      - ./config/jvb:/config:Z
    environment:
      - XMPP_SERVER=prosody
      - XMPP_DOMAIN=${XMPP_DOMAIN}
      - XMPP_AUTH_DOMAIN=${XMPP_AUTH_DOMAIN}
      - XMPP_INTERNAL_MUC_DOMAIN=${XMPP_INTERNAL_MUC_DOMAIN}
      - JVB_AUTH_PASSWORD=${JVB_AUTH_PASSWORD}
      - TZ=${TZ}

networks:
  meet.jitsi:
    driver: bridge
YML

echo "[6/8] Открываю firewall (если UFW установлен)…"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp   || true
  ufw allow 443/tcp  || true
  ufw allow 10000/udp || true
fi

echo "[7/8] Запускаю стек…"
docker compose -f "${COMPOSE_FILE}" --env-file .env up -d

echo "[8/8] Проверяю контейнеры…"
docker compose -f "${COMPOSE_FILE}" ps
echo
echo "✅ Готово! Открой https://${DOMAIN}"
echo "Если LE-сертификат не подтянулся — проверь, что DNS домена указывает на этот сервер и порт 80/443 открыт."
