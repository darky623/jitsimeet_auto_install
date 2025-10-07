🚀 Jitsi Meet Docker Auto-Install Script

Полная установка Jitsi Meet в Docker на Ubuntu 22.04+ за несколько минут.
Поддерживает CloudSell VPS, бесплатные домены и автоматическое получение SSL-сертификата от Let's Encrypt.

✨ Возможности

✅ Автоматическая установка Docker и Docker Compose

✅ Настройка официального Jitsi Meet Docker-стека

✅ Автоматическое создание .env и выпуск сертификатов

✅ Совместимость с бесплатными доменами (например, ddns.net, freenom)

✅ Готово к использованию после запуска скрипта


📋 Требования
ОС: Ubuntu 22.04+
Доступ: root или sudo
Домен: любой, указывающий на IP вашего сервера (например, jitsi.ddns.net)


⚙️ Установка шаг за шагом
🧩 1. Скачайте установочный скрипт
```
wget https://raw.githubusercontent.com/darky623/jitsimeet_auto_install/refs/heads/main/install_jitsi.sh
```

🧩 2. Отредактируйте настройки
Откройте файл в nano:
```
nano install_jitsi.sh
```

В начале файла укажите свои значения:
```
DOMAIN="jitsee.ddns.net"
EMAIL="your@email.com"
```

Сохраните и закройте файл (Ctrl + X -> Y -> Enter).

🧩 3. Запустите установку
```
sudo bash install_jitsi.sh
```

Скрипт автоматически:

 - обновит пакеты на сервере,

 - установит Docker и Docker Compose,

 - скачает официальный Docker-репозиторий Jitsi,

 - создаст конфигурацию с вашим доменом,

 - выпустит SSL-сертификат,

 - запустит контейнеры (web, prosody, jicofo, jvb).

🌐 После установки
Перейдите в браузере по адресу: https://ваш-домен

Если всё прошло успешно — вы увидите интерфейс Jitsi Meet 🎉
