#!/usr/bin/env bash
# Jitsi Meet автоустановка на Ubuntu 22.04+
# Обновление пакетов, выпуск Let's Encrypt, настройка домена и установка Jitsi
# Запуск: sudo bash install_jitsi.sh

set -euo pipefail

### ====== НАСТРОЙКИ ======
DOMAIN="meet.example.com"          # ← укажите ваш домен
EMAIL="admin@example.com"          # ← email для Let's Encrypt
ENABLE_UFW="yes"                   # yes/no — настраивать ли UFW (firewall)

### ====== ПРОВЕРКИ ======
if [[ $EUID -ne 0 ]]; then
  echo "Запустите скрипт от root: sudo bash $0"
  exit 1
fi

echo "[1/8] Проверяю, что домен указывает на этот сервер…"
PUB_IP="$(curl -fsSL https://api.ipify.org || true)"
if [[ -z "${PUB_IP}" ]]; then
  echo "Предупреждение: не удалось определить публичный IP. Пропускаю проверку DNS."
else
  DNS_IP="$(getent ahosts "$DOMAIN" | awk 'NR==1{print $1}' || true)"
  if [[ -z "${DNS_IP}" ]]; then
    echo "Предупреждение: не удалось получить A/AAAA запись для $DOMAIN. Убедитесь, что DNS настроен."
  else
    echo "Публичный IP сервера: ${PUB_IP}; DNS для ${DOMAIN}: ${DNS_IP}"
    if [[ "${DNS_IP}" != "${PUB_IP}" ]]; then
      echo "ВНИМАНИЕ: ${DOMAIN} сейчас не указывает на ${PUB_IP}. Let's Encrypt может не выдать сертификат."
      echo "Продолжаю, но выпуск сертификата может провалиться."
    fi
  fi
fi

echo "[2/8] Обновляю систему и базовые утилиты…"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
apt-get install -y curl gnupg2 apt-transport-https ca-certificates software-properties-common debconf-utils lsb-release

echo "[3/8] Устанавливаю hostname = ${DOMAIN}…"
hostnamectl set-hostname "${DOMAIN}"

echo "[4/8] Добавляю репозиторий Jitsi…"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/" > /etc/apt/sources.list.d/jitsi-stable.list
apt-get update -y

echo "[5/8] Преднастраиваю debconf для бесшумной установки…"
# Указываем домен пакету jitsi-meet
echo "jitsi-meet jitsi-meet/hostname string ${DOMAIN}" | debconf-set-selections
# На этапе установки выберем временный самоподписанный сертификат,
# потом заменим его Let's Encrypt скриптом от Jitsi
echo "jitsi-meet jitsi-meet/cert-choice select Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)" | debconf-set-selections

echo "[6/8] Устанавливаю Jitsi Meet (это поставит nginx, prosody, jicofo, jvb)…"
DEBIAN_FRONTEND=noninteractive apt-get install -y jitsi-meet

echo "[7/8] Выпускаю и подключаю сертификат Let's Encrypt для ${DOMAIN}…"
# Скрипт Jitsi задаст один вопрос — email; передадим его через stdin
if command -v certbot >/dev/null 2>&1; then
  echo "certbot уже установлен."
fi
# Скрипт сам настроит nginx-конфиг на /etc/letsencrypt/live/${DOMAIN}/
if [[ -x /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh ]]; then
  printf "%s\n" "${EMAIL}" | /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
else
  echo "Не найден install-letsencrypt-cert.sh — проверите установку jitsi-meet."
  exit 1
fi

echo "[8/8] Открываю нужные порты в UFW (если включено)…"
if [[ "${ENABLE_UFW}" == "yes" ]]; then
  if ! command -v ufw >/dev/null 2>&1; then
    apt-get install -y ufw
  fi
  ufw allow OpenSSH >/dev/null 2>&1 || true
  ufw allow 80/tcp   >/dev/null 2>&1 || true
  ufw allow 443/tcp  >/dev/null 2>&1 || true
  ufw allow 10000/udp >/dev/null 2>&1 || true
  # Рекомендуемые порты для TURN (опционально, если нужен внешний TURN)
  ufw allow 3478/udp  >/dev/null 2>&1 || true
  ufw allow 5349/tcp  >/dev/null 2>&1 || true
  # Включать UFW автоматически опасно, включите вручную если надо:
  echo "UFW правила добавлены. Включить firewall: 'ufw enable' (проверьте доступ по SSH!)."
fi

echo "Перезапускаю службы…"
systemctl restart nginx || true
systemctl restart prosody || true
systemctl restart jicofo || true
systemctl restart jitsi-videobridge2 || true

echo "Готово! Проверьте: https://${DOMAIN}"
echo "Если сертификат не выпустился — перепроверьте DNS A/AAAA запись домена и повторите шаг с Let's Encrypt:"
echo "  printf \"%s\\n\" \"${EMAIL}\" | /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh"
