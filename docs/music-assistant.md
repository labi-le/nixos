# Music Assistant на Станции 1

Готовый серверный плеер вместо самописной морды: UI на `http://192.168.1.2:8095`,
звук уходит на станцию через Snapcast-клиент на Android.

## Состав

| Что | Где |
|---|---|
| сервер | контейнер `ghcr.io/music-assistant/server` (`modules/music-assistant.nix`), host-network, состояние в `/var/lib/music-assistant` |
| библиотека | `/drive/sync/music` смонтирована в контейнер read-only как `/media`, в MA добавлена как Filesystem-провайдер |
| порты | 8095 UI, 8097 стрим, 1704/1705 Snapcast, 4953-5153 клиенты |
| клиент на станции | `de.badaix.snapcast` (Snapdroid), APK с GitHub releases, host `192.168.1.2`, порты 1704/1705 |

MA сам поднимает встроенный Snapserver; отдельный snapcast-сервер не нужен.

## Первичная настройка

1. Открыть `:8095`, создать админ-аккаунт.
2. Settings → Music sources → **Add a music source** → Filesystem (local disk), путь `/media`. Импорт идёт в фоне.
3. Settings → Player providers → **Add a player provider** → Snapcast.
4. На станции поставить Snapdroid, в его настройках указать хост `192.168.1.2`, включить Auto start Snapclient.

## Почему станция «не видна»

MA считает Snapcast-клиента доступным только пока Snapserver видит свежий `lastSeen`
(порог 15 с, `SNAPCLIENT_STALE_THRESHOLD`). Клиент после падения/перезапуска сам не
поднимается, пока приложение не откроют: у Snapdroid есть ресиверы на
`de.badaix.snapcast.START_SERVICE` и `BOOT_COMPLETED`, поэтому headless-запуск — это

```sh
adb shell am broadcast -a de.badaix.snapcast.START_SERVICE -n de.badaix.snapcast/.BroadcastReceiver
```

Без этого в списке игроков MA остаются только `pc` и веб-плеер, а строка станции
показывается в Settings → Players с `available: false`.

`am startservice -n de.badaix.snapcast/.SnapclientService` клиента не поднимает —
использовать broadcast.

## TIDAL

Settings → Music sources → Add a music source → Tidal. MA показывает код и ссылку
`link.tidal.com`: ввести код на телефоне/в браузере, вкладка настроек обновится сама.
Логин не нужен ни для локальной библиотеки, ни для Snapcast — только для стриминга TIDAL.

## Фоновый анализ громкости

MA считает loudness/EBU R128 для локальных файлов ночным фоновым сканом, чтобы играть ReplayGain без клиппинга. Расписание лежит в `/var/lib/music-assistant/settings.json` (`core.tasks.scheduled_task_states.audio_analysis_background_scan`) в UTC, а дефолт сервер берёт от локальной полуночи — то есть 21:00 UTC, и скан молотил CPU с 00:00.

Окно задаётся в `modules/music-assistant.nix`: `ExecStartPre` контейнера прогоняет `jq` по `settings.json` и ставит расписание на 01:00 UTC = 04:00 MSK. Правка применяется на каждом старте контейнера, поэтому смена окна через UI не переживёт рестарта — менять только в модуле. Прогон ограничен четырьмя часами (`BACKGROUND_SCAN_RUN_BUDGET_SECONDS` в образе), значит ночь занимает 04:00–08:00 максимум и обычно заканчивается раньше: в окно попадает только накопленное с прошлой ночи.

## Поведение

- Задержка около секунды на play/pause: это буфер Snapcast.
- Пауза реализована как STOP+RESUME — состояние в UI может не показывать `paused`.
- Эквалайзер станции не участвует: звук идёт через AudioFlinger (OpenSL).
- Громкость — см. раздел ниже.
- Пока играет Snapcast, Алиса молчит; после остановки возвращается.

## Громкость

Слайдер MA — это `Client.SetVolume` Snapcast, то есть софт-громкость клиента.
Усилитель станции при этом закреплён на максимуме: его шкала в дБ (0…672, шаг
дробный), и без закрепления проценты MA перемножались с аппаратным затуханием —
30 % звучали как тишина.

| Слой | Шкала | Кто пишет |
|---|---|---|
| софт-громкость клиента | 0…100 % | MA, крутилка через мост |
| усилитель, card1 | `Tweeters/Subwoofer Master Playback Volume`, 0…672 | `ampmax.sh` держит 672/662, откатывая записи quasar |

Крутилка: quasar (`volume_setd`) пишет `hw_master_volume` 0…85. `knob.sh` слушает
`logcat -s volume_setd`, переводит `n` в `n*100/85` и шлёт `Client.SetVolume` на
`192.168.1.2:1705`; MA обновляет слайдер сам, без запроса.

Скрипты живут на станции, в репозитории их нет:

| Файл | Роль |
|---|---|
| `/data/local/etc/netlock.sh` | iptables-блок Яндекса, LAN остаётся |
| `/data/local/etc/ampmax.sh` | раз в секунду возвращает усилитель на 672/662 |
| `/data/local/etc/knob.sh` | крутилка → `Client.SetVolume` |
| `/data/local/etc/station-watch.sh` | раз в 30 с перезапускает всё выше по pidfile и поднимает snapclient |

Запуск — строка в конце `/system/vendor/quasar/onboot.sh`.

## YAM

`yamd` — менеджер `.yap`-пакетов для станций. Лежит в `/data/quazar/yam/bin/yamd`,
данные в `/data/quazar/yam/data`, веб-панель на `:8099` без пароля (только LAN).
Стартует от root и перезапускается тем же `station-watch.sh`, поэтому переживает ребут.

Модель определяется как `unknown`: профиля Станции 1 в YAM нет, поэтому пакеты с
привязкой к модели откажутся ставиться. Доступные фичи: Lua-runtime, `.yap`-плагины,
`input.evdev`, `led.sysfs`, датчик температуры, батарея.

CLI на pc — пакет `pkgs/yam.nix` через overlay, `yam` в PATH. Адрес колонки CLI
находит сам по adb. Команды: `yam registry list` (75 пакетов), `yam install <id>`,
`yam logs <id>`.

## SSH

`dropbear` из реестра yam (aarch64 musl) распакован в `/data/local/dropbear` и поднимается
`station-watch.sh` на порт **22** только по ключам (`-s`); ключи — `/data/root/.ssh/authorized_keys`.
Хостовый ключ — `/data/local/dropbear/hk_ed25519`, лог — `dropbear.log` рядом.

Android не отдаёт passwd-базу, и dropbear без неё отказывает: сначала «Login attempt for
existent user», затем «invalid shell». Поэтому в `/system` дописаны два файла (раздел
перемонтируется в rw на время правки):

| Файл | Содержимое |
|---|---|
| `/system/etc/passwd` | `root:x:0:0:root:/data/root:/system/bin/sh` |
| `/system/etc/shells` | `/system/bin/sh` |

Отсюда следствие: пароль у root не работает в принципе (`x` в поле пароля), вход только по ключу.
Вход: `ssh root@192.168.1.148`. Telnet на 2323 (busybox из пропатченного ramdisk)
остаётся запасным путём, если SSH перестанет подниматься.

## OTA, телеметрия и логи

Обновления закрыты скриптом из вики — он лежит в `/data/opt/yandex-noupdate.sh`:

```sh
export PATH=/data/opt/bin:$PATH     # скрипту нужен awk, в non-login сессии его нет
sh /data/opt/yandex-noupdate.sh
sh /data/opt/yandex-noupdate.sh status
# launch.json : updatesd убран
# applier     : заглушён
# ota key     : подменён
```

Три рубежа: `ota_script.pub` заменён чужим ключом (любой OTA не пройдёт проверку подписи),
`device_ota_update.sh` — заглушка, `updatesd` выброшен из `launch.json`. Оригиналы —
`/data/opt/backup`, возврат — `sh /data/opt/yandex-noupdate.sh restore`.

Из `launch.json` также вырезаны `telemetry` (AppMetrica) и `fluent-bitd` (отправка
`/data/quasar/daemons_logs/*.log` в `clck.yandex.net`). Остались только `--platformd`
и `--mediad`, glagol на 1961 отвечает. Бэкапы конфига: `/data/local/etc/launch.json.orig`
(исходный, с телеметрией) и `launch.before-fluent.json`.

Штатный `q restart` на Android-станции не работает: внутри `killall`, которого в toybox нет —
печатает `killall: not found` и возвращает «quasar is already running». Перезапускать вручную:

```sh
cd /system/vendor/quasar
/system/bin/busybox-smp killall quasar_launcher2
sleep 5
/system/bin/busybox-smp killall -9 maind
sh run.sh
```

После этих правок `netlock` открыт постоянно (`/data/local/etc/net-open` лежит в `/data`,
поэтому состояние переживает ребут): сеть нужна Алисе, а OTA и логи для неё уже закрыты
другими средствами. Закрыть обратно — `netclose`.

Остаточный риск: облачная директива сброса. На Buildroot-станциях её гасят заглушкой
`enter_factory_mode.sh`, но на Android-прошивке такого скрипта нет (`/system/vendor/quasar`
содержит только `device_ota_update.sh`), поэтому стубить нечего — сброс пойдёт внутрь `maind`.
Страховка — бэкап конфига вне станции, снятый после настройки:
`/tmp/nix/station-config-2026-10-26.tgz` (внутри `/data/local/etc`, `/data/root`,
`/data/opt/bin`, passwd/shells/resolv.conf, launch.json).

## Entware и yse

`yse` залит в `/data/opt/bin/yse`, `yse bootstrap` развернул Entware в `/data/opt/entware`
(`/opt` — симлинк на него). `opkg` — `/opt/bin/opkg`, в индексе ~2960 пакетов; оба источника
проверены: `opkg install htop` (Entware) и `yse install yap:jq` (реестр yapkg, 76 пакетов).
Ставится всё в `/data`, `/system` не затрагивается.

Под Android-станцию пришлось доделать то, чего нет в Buildroot-рецепте:

| Проблема | Решение |
|---|---|
| нет `awk`, `sha256sum`, `gunzip` в toolbox | симлинки в `/data/opt/bin` на `/system/bin/busybox-smp` |
| `busybox df -k` переносит длинное имя устройства на отдельную строку, `yse` читает `$4` второй строки | обёртка `/data/opt/bin/df`, склеивающая перенос |
| нет `wget`, а busybox wget не умеет TLS | shim `/data/opt/bin/wget` поверх `/bin/curl`, внутри `unset LD_LIBRARY_PATH` (иначе `opkg` передаёт свой `LD_LIBRARY_PATH=/opt/lib` и системный curl падает в SIGSEGV) |
| у Entware-бинарников нет резолвера: Android держит DNS в `net.dns1`, файла нет | `/etc/resolv.conf` (`nameserver 192.168.1.1`), лежит в `/system/etc` |
| нет каталогов `/tmp` и `/opt` | симлинки на `/data/local/tmp` и `/data/opt/entware`; `station-watch.sh` пересоздаёт их после ребута |
| `/etc/profile.d` никто не читает | PATH в `/data/root/.profile` (mksh читает его для login-сессий) |

Сеть: `netlock.sh` держит станцию в режиме LAN-only, поэтому `opkg`/`yse` без интернета не
работают. Переключатель — две команды в `/data/opt/bin`:

```sh
netopen            # снять блокировку + default-маршрут в legacy_network
netopen 10         # то же, но само закроется через 10 минут
yse install git    # или yse update
netclose
```

Локальная копия `contrib/install-yse.sh` правится только в одном месте: порт SSH вынесен в
`YSE_SSH_PORT` (по умолчанию 2222, у нас 22).
