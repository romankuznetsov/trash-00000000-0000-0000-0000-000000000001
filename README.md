# qWDTT OpenWrt

[![Build](https://github.com/romankuznetsov/qwdtt-openwrt/actions/workflows/build.yml/badge.svg)](https://github.com/romankuznetsov/qwdtt-openwrt/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/romankuznetsov/qwdtt-openwrt)](https://github.com/romankuznetsov/qwdtt-openwrt/releases/latest)
[![Release date](https://img.shields.io/github/release-date/romankuznetsov/qwdtt-openwrt)](https://github.com/romankuznetsov/qwdtt-openwrt/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/romankuznetsov/qwdtt-openwrt/total)](https://github.com/romankuznetsov/qwdtt-openwrt/releases)

RAW-IP клиент qWDTT для роутеров OpenWrt. Он поднимает интерфейс `qwdtt0` и
направляет через туннель IPv4-трафик устройств локальной сети. Сам роутер
сохраняет прямой доступ к WAN, поэтому соединения с VK TURN не зацикливаются.

Поддерживается только RAW-IP. WireGuard и SOCKS в этой сборке намеренно не
включены.

## Что понадобится

- Роутер с OpenWrt 25.12+ или совместимой версией с `procd` и `firewall4`.
- Пакеты `ip-full`, `kmod-tun`, `ca-bundle` - устанавливаются автоматически
  вместе с пакетами qWDTT.
- Сервер qWDTT с включённым RAW-слушателем. Обычно это UDP-порт `56003`.
- Данные подключения: адрес сервера, пароль и хеш звонка VK.

## Быстрый запуск

Два способа установить пакеты. Настройка после установки одинаковая - см.
раздел "После установки".

### Способ 1: через LuCI (без SSH)

Полностью через веб-интерфейс. Порядок зависит от менеджера пакетов: `apk` на
OpenWrt 25.x, `opkg` на 24.10.

#### OpenWrt 25.x (apk)

Отдельные `.apk` не подписаны, поэтому доверие дает ключ feed, а не загрузка
файлов пакетов - загруженный через LuCI пакет ставится недоверенным.

1. Установите ключ доверия. Скачайте `qwdtt-apk-key.tar.gz` со страницы
   [Releases](../../releases/latest) и восстановите архив в
   System -> Backup / Flash Firmware -> "Restore". Он кладет публичный ключ в
   `/etc/apk/keys` - без него feed недоверенный.
2. Добавьте feed. В System -> Software -> Configuration допишите строку для
   своей архитектуры (полный список - на
   [странице feed](https://romankuznetsov.github.io/qwdtt-openwrt/)), например
   для `aarch64_cortex-a53`:

   ```
   https://romankuznetsov.github.io/qwdtt-openwrt/packages/aarch64_cortex-a53/packages.adb
   ```

   Сохраните, затем нажмите "Update lists…".
3. В System -> Software установите пакеты `qwdtt`, `luci-app-qwdtt`,
   `qwdtt-client` и `ip-full`.

#### OpenWrt 24.10 (opkg)

apk-feed недоступен, но opkg ставит локальный `.ipk` без подписи, поэтому
загрузка файлов работает. Клиент здесь - `.ipk` с уже собранным бинарником, а не
сборка из исходников: SDK 24.10 её не осилит.

1. Со страницы [Releases](../../releases/latest) скачайте:
   - `qwdtt_*.ipk` и `luci-app-qwdtt_*.ipk` (архитектура `all`);
   - `qwdtt-client_*_<ARCH>.ipk` для своей архитектуры. Доступны четыре, те же,
     что и в apk-feed для 25.x: `x86_64`, `aarch64_cortex-a53`,
     `arm_cortex-a7_neon-vfpv4`, `mipsel_24kc`;
   - при желании `luci-i18n-qwdtt-ru_*.ipk`.
2. В System -> Software нажмите "Update lists…", затем установите зависимости
   `ca-bundle`, `kmod-tun`, `ip-full` (поиском по списку).
3. Там же кнопкой "Upload Package…" загрузите и установите каждый скачанный
   `.ipk`.

### Способ 2: одной командой (SSH)

От `root` на роутере (OpenWrt 25.x, `apk`):

```sh
wget -qO- https://raw.githubusercontent.com/romankuznetsov/qwdtt-openwrt/main/install.sh | sh
```

Скрипт добавляет подписанный feed и его ключ доверия, затем ставит `qwdtt`,
`luci-app-qwdtt`, `qwdtt-client` и зависимости. Флаг `-e` пропускает русский
перевод LuCI. Для OpenWrt 24.10 и старше (`opkg`) apk-feed недоступен - см.
Способ 1, раздел "OpenWrt 24.10".

### После установки

1. Задайте адрес сервера, пароль и хеши звонка - через LuCI
   (Services -> qWDTT -> Settings) или через UCI:

   ```sh
   uci set qwdtt.main.peer_host='IP_АДРЕС_СЕРВЕРА'
   uci set qwdtt.main.peer_port='56003'
   uci set qwdtt.main.password='ПАРОЛЬ'
   uci add_list qwdtt.main.hash='ХЕШ_ЗВОНКА'
   uci commit qwdtt
   ```

   Пароль и хеш нельзя публиковать или отправлять посторонним.

2. Включите автозапуск и запустите сервис - кнопкой Start на странице
   Services -> qWDTT в LuCI, или из шелла:

   ```sh
   /etc/init.d/qwdtt enable
   /usr/bin/qwdtt start
   ```

## Проверка

Логи подключения:

```sh
logread -e qwdtt
```

Рабочее подключение пишет `RAW-конфиг получен`, затем `TUN подключён, трафик
пошёл`. Проверить интерфейс и правило маршрутизации можно так:

```sh
ip addr show qwdtt0
ip rule show
ip route show table 51820
```

Проверка создания TUN без данных VK и сервера:

```sh
/usr/bin/qwdtt-client -rawtun-self-test 10.70.0.2
```

## Настройка

Все настройки хранятся в UCI (`/etc/config/qwdtt`) и правятся через LuCI
(Services -> qWDTT -> Settings) или командой `uci`. Значения по умолчанию
задает [`qwdtt/files/qwdtt.config`](qwdtt/files/qwdtt.config).

`lan_interface` по умолчанию - `br-lan`. Если в вашей сборке OpenWrt LAN
называется иначе, поменяйте это поле. При изменении `tun_name` нужно также
изменить устройство зоны `qwdtt` в конфигурации firewall.

Остановить клиент:

```sh
/etc/init.d/qwdtt stop
```

## Архитектуры сборок

| Артефакт | Для чего |
| --- | --- |
| `x86_64` | x86-роутеры и виртуальные машины |
| `aarch64` | современные ARM64-роутеры |
| `armv7` | 32-битные ARMv7-устройства |
| `mipsel` | старые MIPS little-endian роутеры |

Перед скачиванием можно проверить архитектуру командой `uname -m`.
