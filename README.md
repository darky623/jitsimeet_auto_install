<h1>Jitsi Meet Auto-Install</h1>

Полная установка Jitsi Meet в Docker на Ubuntu 22.04+ за несколько минут.
Поддерживает CloudSell VPS, бесплатные домены и автоматическое получение SSL-сертификата от Let's Encrypt.

<h2>Возможности</h2>

 - Автоматическая установка Docker и Docker Compose
 - Настройка официального Jitsi Meet Docker-стека
 - Автоматическое создание .env и выпуск сертификатов
 - Совместимость с бесплатными доменами (например, ddns.net, freenom)
 - Готово к использованию после запуска скрипта

<h2>Требования</h2>

 - ОС: Ubuntu 22.04+
 - Доступ: root или sudo
 - Домен: любой, указывающий на IP вашего сервера (например, jitsi.ddns.net)

<h2>Установка</h2>
<h3>1. Скачайте установочный скрипт</h3>

```
wget https://raw.githubusercontent.com/darky623/jitsimeet_auto_install/refs/heads/main/install_jitsi.sh
```

<h3>2. Отредактируйте настройки</h3>
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

<h3>3. Запустите установку</h3>

```
sudo bash install_jitsi.sh
```

<h2>Скрипт автоматически:</h2>

 - обновит пакеты на сервере,
 - установит Docker и Docker Compose,
 - скачает официальный Docker-репозиторий Jitsi,
 - создаст конфигурацию с вашим доменом,
 - выпустит SSL-сертификат,
 - запустит контейнеры (web, prosody, jicofo, jvb).

<h2>После установки</h2>
Перейдите в браузере по адресу: 

```
https://ваш-домен
```
Если всё прошло успешно — вы увидите интерфейс Jitsi Meet
