# qWDTT OpenWrt

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

1. Установите пакеты одной командой от `root` (OpenWrt 25.x, `apk`):

   ```sh
   wget -qO- https://raw.githubusercontent.com/romankuznetsov/qwdtt-openwrt/main/install.sh | sh
   ```

   Скрипт добавляет подписанный feed и его ключ доверия, затем ставит `qwdtt`,
   `luci-app-qwdtt`, `qwdtt-client` и зависимости. Флаг `-e` пропускает русский
   перевод LuCI. На OpenWrt 24.10 и старше (`opkg`) feed недоступен - установите
   пакеты вручную из [Releases](../../releases/latest).

2. Задайте адрес сервера, пароль и хеши звонка - через LuCI
   (Services -> qWDTT -> Settings) или через UCI:

   ```sh
   uci set qwdtt.main.peer_host='IP_АДРЕС_СЕРВЕРА'
   uci set qwdtt.main.peer_port='56003'
   uci set qwdtt.main.password='ПАРОЛЬ'
   uci add_list qwdtt.main.hash='ХЕШ_ЗВОНКА'
   uci commit qwdtt
   ```

   Пароль и хеш нельзя публиковать или отправлять посторонним.

3. Включите автозапуск и запустите сервис:

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
