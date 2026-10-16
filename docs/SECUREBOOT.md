# Secure Boot со своими ключами + TPM2: защита загрузки до LUKS

Продолжение `docs/LUKS-MIGRATION.md`. Инструкция для исполнителя (человека или
ИИ-агента).

**Целевая машина: `yoga14`** (Lenovo Yoga 7 14ILL10, Intel Core Ultra 7 258V,
Lunar Lake). Конфигурация — `devices/yoga14/`, сборка — `nixosConfigurations.yoga14`.

> **Внимание, источник путаницы.** Каталог репозитория называется
> `my-nix-config-huawei`, но это общий конфиг на несколько машин. Каталоги
> `devices/huawei-rlef-x/`, `devices/asus-ux3405m/`, `devices/desktop/` —
> **другие машины, не трогать**.

> **Предусловие.** LUKS уже включён и работает: см.
> `devices/yoga14/hardware-configuration.nix:30` (`boot.initrd.luks.devices."cryptroot"`).
> Если система ещё не зашифрована — сначала `docs/LUKS-MIGRATION.md` целиком.

> **Читай целиком до начала.** Фаза 3 (enroll ключей) переводит машину в
> состояние, где неподписанное не грузится. Ошибка здесь = загрузка только с
> live-USB и ручной сброс ключей в UEFI. Аварийные процедуры — раздел 8.

---

## 1. Зачем это: что закрывает LUKS и что остаётся открытым

LUKS закрывает ровно один сценарий: **диск вынули из выключенного ноутбука**.
Всё остальное — открыто:

| Атака | Почему сейчас проходит |
|---|---|
| Evil maid: подмена ядра/initrd | `/boot` — vfat без подписи. Свой initrd сливает пароль LUKS при следующем вводе |
| Загрузка чужой ОС с USB | Secure Boot выключен (шаг 0.6 LUKS-инструкции), пароля в UEFI нет |
| DMA-атака через Thunderbolt | `thunderbolt` в initrd (`hardware-configuration.nix:15`); IOMMU есть, но `iommu=pt`, без `efi=disable_early_pci_dma` |
| Кража включённого/спящего ноутбука | Ключ LUKS в RAM; suspend-to-RAM его не стирает |

**Secure Boot сам по себе от evil maid не спасает.** Заводская база ключей
содержит сертификаты Microsoft, которыми подписан shim — а им можно загрузить
что угодно. Работает только связка:

```
свои ключи (lanzaboote) + пароль UEFI + запрет boot с USB + LUKS-ключ, привязанный к PCR 7
```

Каждый элемент без остальных обходится:
- ключи без пароля UEFI → атакующий заходит в BIOS и выключает Secure Boot;
- Secure Boot без TPM-привязки → выключение SB не мешает ввести пароль руками,
  подменённый загрузчик всё ещё соберёт его;
- TPM без PIN → украденный ноутбук расшифровывает себя сам.

---

## 2. Исходное состояние конфига

Проверено по репозиторию:

| Что | Где | Значение |
|---|---|---|
| Загрузчик | `configuration.nix:149` | `boot.loader.systemd-boot.enable = true` (общий для всех машин) |
| LUKS | `devices/yoga14/hardware-configuration.nix:30` | `cryptroot`, `allowDiscards = true` |
| initrd | — | обычный (не systemd); `boot.initrd.systemd.enable` не задан |
| IOMMU | `devices/yoga14/default.nix` (`kernelParams`) | `intel_iommu=on`, `iommu=pt` — уже есть |
| Out-of-tree модули | `hardware-configuration.nix:27`, `default.nix` | `v4l2loopback`, `akvcam`, плюс `vfio-pci`/`uio_pci_generic` в initrd |
| Сборка | `flake.nix:191` | `yoga14 = mkSystem "yoga14" [ ... ]` |
| TPM | железо | присутствует (`/sys/class/tpm/tpm0`) |

**Важное следствие про out-of-tree модули:** `akvcam` и `v4l2loopback` собираются
локально и не подписаны ключом ядра. Сам Secure Boot их не блокирует (NixOS не
включает enforcement подписи модулей), но `lockdown=confidentiality` — заблокирует.
Поэтому lockdown вынесен в отдельную необязательную фазу 6 и включается через
`integrity`, а не сразу.

---

## 3. Последовательность действий

Фазы 1–5 — основной путь, делать подряд. Фазы 6–7 — необязательные усиления,
каждая после подтверждённо работающей предыдущей.

### Фаза 0. Проверки перед стартом

0.1. Система загружается с паролем LUKS, всё работает (раздел 6 LUKS-инструкции
пройден).

0.2. Бэкап LUKS-заголовка на месте (раздел 2.3 LUKS-инструкции). Если его нет —
сделать сейчас, до всяких экспериментов с загрузкой.

0.3. **Live-USB с NixOS записан и проверен** — им придётся чинить, если фаза 5
не загрузится. Флешку не вынимать до конца операции.

0.4. Конфиг запушен:

```bash
cd /home/bg/Documents/code/github.com/back2nix/nix/my-nix-config-huawei
git status && git push
```

0.5. Ноутбук в розетку.

0.6. Записать текущее состояние — понадобится для сверки:

```bash
bootctl status | head -20        # ожидается Secure Boot: disabled
sudo tpm2_pcrread sha256:7       # если tpm2-tools нет: nix shell nixpkgs#tpm2-tools
```

---

### Фаза 1. Пароль UEFI и загрузочные устройства

Самая дешёвая часть, даёт больше всего. Без неё все следующие фазы отменяются
одним заходом в BIOS.

Зайти в UEFI (Fn+F2 или Novo-кнопка на Lenovo):

1.1. **Security → Set Supervisor Password.** Задать и записать в менеджер
паролей. Без supervisor-пароля любой желающий выключит Secure Boot и загрузится
с флешки.

> Пароль UEFI на Lenovo сбрасывается только сервисом (не перемычкой). Потеря =
> визит в сервис. Записать в двух местах.

1.2. **Boot → отключить USB Boot и Network/PXE Boot.** Оставить только внутренний
NVMe. На время операции USB-загрузка ещё нужна — вернуться к этому пункту после
фазы 5.

1.3. **Security → Thunderbolt (если есть пункт) → security level = User
Authorization**, не `Legacy`/`None`. Закрывает DMA с неавторизованных
TB-устройств до входа в ОС.

1.4. Secure Boot пока **не включать** — сначала фаза 3 переведёт его в Setup Mode.

---

### Фаза 2. Подключение lanzaboote

`lanzaboote` собирает ядро + initrd + cmdline в единый подписанный UKI и ставит
свой EFI-стаб вместо `systemd-boot`. Прошивка откажется грузить UKI, подписанный
не твоим ключом — подменённый initrd просто не стартует.

#### 2.1. Вход во flake

В `flake.nix`, в блок `inputs`:

```nix
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

Модуль подключить **только для yoga14** (`flake.nix:191`), чтобы не задеть
остальные машины:

```nix
          yoga14 = mkSystem "yoga14" [
            inputs.nixos-hardware.nixosModules.lenovo-yoga-7-14ILL10
            inputs.lanzaboote.nixosModules.lanzaboote
          ];
```

#### 2.2. Конфигурация машины

В `devices/yoga14/default.nix`, внутри блока `boot = { ... }` (соседи —
`kernelPackages`, `kernelParams`):

```nix
    # Secure Boot со своими ключами. systemd-boot включён глобально в
    # configuration.nix:149, здесь его нужно перебить — lanzaboote ставит
    # собственный EFI-стаб и с systemd-boot конфликтует.
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
```

И рядом, вне блока `boot`:

```nix
  environment.systemPackages = [ pkgs.sbctl ];
```

> `pkiBundle = "/var/lib/sbctl"` — путь для lanzaboote ≥ 0.4. В старых примерах
> из интернета встречается `/etc/secureboot`; для 0.4.x он вызовет предупреждение
> о deprecated-пути. Если ключи уже созданы по старому пути — перенести каталог.

`lib` в аргументах `devices/yoga14/default.nix` уже есть — дополнительно ничего
импортировать не нужно.

#### 2.3. Первая сборка — ещё БЕЗ ключей

```bash
sudo nixos-rebuild switch --flake .#yoga14
```

Сборка пройдёт, `sbctl` появится в системе. Загрузка пока работает как раньше
(Secure Boot выключен, прошивка грузит что дают). **Проверить, что система
перезагружается**, прежде чем идти дальше:

```bash
sudo reboot
# после входа:
bootctl status | head -20   # Secure Boot: disabled (setup) ИЛИ disabled
```

Если на этом шаге система не загрузилась — виновата не подпись, а конфиг
загрузчика; чинить по разделу 8 «Не загружается после фазы 2».

---

### Фаза 3. Свои ключи

#### 3.1. Setup Mode в UEFI

В UEFI: **Security → Secure Boot → Reset to Setup Mode** (у Lenovo пункт может
называться `Clear All Secure Boot Keys` / `Erase all Secure Boot Settings`).
Secure Boot при этом остаётся **выключенным** — включим на шаге 3.5.

Проверить после загрузки:

```bash
sudo sbctl status
# ожидается: Setup Mode: ✓ Enabled, Secure Boot: ✗ Disabled
```

Если `Setup Mode: Disabled` — прошивка не сбросила базу ключей, вернуться в UEFI.

#### 3.2. Создать ключи

```bash
sudo sbctl create-keys
```

Создаст PK/KEK/db в `/var/lib/sbctl`. Операция локальная, ничего ещё не меняет
в прошивке.

#### 3.3. Подписать текущее поколение

```bash
sudo nixos-rebuild switch --flake .#yoga14
sudo sbctl verify
```

`sbctl verify` должен показать `✓ Signed` для всех `.efi` в `/boot/EFI`.

> Нормально, что несколько файлов помечены как неподписанные, если это остатки
> старого `systemd-boot` в `/boot/EFI/systemd/` — они больше не используются.
> Всё, что относится к `/boot/EFI/Linux/` и `/boot/EFI/BOOT/BOOTX64.EFI`,
> **обязано** быть подписано. Если нет — не переходить к 3.4.

#### 3.4. Enroll ключей в прошивку — точка невозврата

```bash
sudo sbctl enroll-keys --microsoft
```

**Флаг `--microsoft` обязателен на этой машине.** Он сохраняет в db сертификаты
Microsoft вдобавок к твоим. Причина не в Windows: на Lunar Lake подписанные
Microsoft OpROM/firmware-блобы (в т.ч. графика) при пустой MS-базе могут не
инициализироваться — вплоть до чёрного экрана без вывода. Потеря части
теоретической строгости несопоставима с риском окирпичивания.

Проверить:

```bash
sudo sbctl status   # Setup Mode: ✗ Disabled, ключи установлены
```

#### 3.5. Включить Secure Boot

Перезагрузиться в UEFI, **Secure Boot → Enabled**, сохранить, загрузиться в
NixOS.

#### 3.6. Проверка

```bash
bootctl status | head -20
# Secure Boot: enabled (user)   <- ключевая строка, именно "(user)"
sudo sbctl status
```

`enabled (user)` означает: включён и работает **на твоих** ключах.
`enabled (deployed)` или `(setup)` — что-то пошло не так, разбираться до фазы 4.

#### 3.7. Бэкап ключей — НЕ ПРОПУСКАТЬ

По значимости — как LUKS-заголовок из раздела 2.3 LUKS-инструкции.

```bash
sudo tar czf /root/sbctl-keys-yoga14.tar.gz -C /var/lib sbctl
sudo chmod 600 /root/sbctl-keys-yoga14.tar.gz

# на флешку
sudo cp /root/sbctl-keys-yoga14.tar.gz /mnt/usb/
# на стационарник, рядом с бэкапом LUKS-заголовка
scp /root/sbctl-keys-yoga14.tar.gz bg@BACKUP_HOST:/home/bg/backup-huawei-meta/
```

> Приватный ключ PK/db даёт возможность подписать загрузчик, который эта машина
> примет. Хранить не публично, шифровать при хранении в облаке.
>
> Потеря ключей **не фатальна**: восстановление = Setup Mode в UEFI + `create-keys`
> + `enroll-keys` заново. Но пока ключи не восстановлены, система не грузится.

---

### Фаза 4. TPM2 + PIN, привязка к PCR 7

**Делать только после того, как фаза 3 подтверждённо работает** — иначе слот
придётся перепривязывать дважды (значение PCR 7 меняется при enroll ключей).

#### 4.1. systemd-initrd

TPM2-разблокировка требует systemd в initrd. В `devices/yoga14/default.nix`,
в блок `boot`:

```nix
    initrd.systemd.enable = true;
```

```bash
sudo nixos-rebuild switch --flake .#yoga14
sudo reboot
```

**Перезагрузиться и убедиться, что пароль LUKS всё ещё принимается.** Переход на
systemd-initrd меняет способ запроса пароля (раскладка, приглашение), и ломаться
он должен на этом шаге, а не поверх TPM.

#### 4.2. Привязать слот

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes \
  /dev/nvme0n1p2
```

Спросит существующий пароль LUKS, затем новый **PIN** дважды.

Почему именно так:

- **PCR 7, а не 0+7.** PCR 7 измеряет состояние Secure Boot и базу ключей —
  ровно то, что мы защищаем: выключил SB или подсунул чужой db → TPM не отдаст
  ключ. PCR 0 измеряет прошивку и ломается от **любого** обновления UEFI, а
  защиты сверх PCR 7 в нашей модели почти не добавляет.
- **`--tpm2-with-pin=yes` — не опция, а суть.** Без PIN укравший включённый или
  выключенный ноутбук получает расшифрованный диск автоматически: TPM отдаёт
  ключ сам, ведь Secure Boot в порядке. С PIN работает anti-hammering TPM
  (блокировка после нескольких неверных попыток), поэтому короткий PIN здесь
  надёжнее длинного пароля — брутфорс упирается в железо, а не в скорость argon2.
- **Парольный слот оставить.** Это единственный путь после обновления UEFI,
  сброса TPM или отказа железа. Проверить, что слотов два:

  ```bash
  sudo cryptsetup luksDump /dev/nvme0n1p2 | grep -A2 '^  [0-9]:'
  ```

#### 4.3. Проверка

```bash
sudo reboot
```

При загрузке должен спрашиваться **PIN** (не длинный пароль LUKS). Ввод пароля
LUKS должен по-прежнему работать как запасной путь — проверить сознательно,
нажав Esc / выбрав ввод пароля.

> **Про PCR 11.** Идеальная привязка — PCR 11: systemd-stub измеряет туда сам
> UKI, и подмена ядра запрещает выдачу ключа даже при валидной подписи. Плата:
> значение меняется при **каждом** `nixos-rebuild`, слот надо перезаписывать или
> настраивать `systemd-pcrlock` с подписанной политикой. Для ноутбука с частыми
> ребилдами PCR 7 — разумный баланс: подпись UKI уже проверяется самим Secure
> Boot, а PCR 7 гарантирует, что эта проверка включена.

---

### Фаза 5. Закрыть загрузочные пути

Вернуться в UEFI и доделать пункт 1.2:

- **USB Boot → Disabled**, **Network/PXE Boot → Disabled**;
- Boot order: только внутренний NVMe;
- убедиться, что supervisor-пароль из 1.1 стоит.

Флешку теперь можно вынуть. Для будущего обслуживания USB-загрузка включается
обратно через supervisor-пароль.

---

### Фаза 6 (опционально). Kernel lockdown

Имеет смысл **только** при включённом Secure Boot. Запрещает root'у трогать
`/dev/mem`, грузить неподписанные модули через некоторые пути, `kexec`
неподписанного ядра, писать в MSR — то есть закрывает обход защиты уже изнутри
работающей системы.

> **Риск для этой машины.** В конфиге есть out-of-tree модули: `v4l2loopback`
> (`hardware-configuration.nix:27`), `akvcam` (`default.nix`), плюс `vfio-pci` и
> `uio_pci_generic` в initrd. Режим `confidentiality` может их сломать, а вместе
> с ними — виртуальную камеру и DPDK-сценарии.

Порядок: сначала мягкий режим, в `devices/yoga14/default.nix` → `kernelParams`:

```nix
      "lockdown=integrity"
```

Пожить неделю, проверить камеру/akvcam/vfio. Если всё в порядке и хочется
строже — заменить на `lockdown=confidentiality` и проверить снова. При проблемах
просто убрать параметр и пересобрать — откат бесплатный.

Заодно в тот же список стоит добавить, независимо от lockdown:

```nix
      "efi=disable_early_pci_dma"
```

(закрывает DMA-окно до инициализации IOMMU; `intel_iommu=on` в конфиге уже есть).

И заблокировать заведомо ненужные DMA-транспорты:

```nix
  boot.blacklistedKernelModules = [ "firewire_core" "thunderbolt_net" ];
```

---

### Фаза 7 (опционально). Спящий режим

**Это самая большая оставшаяся дыра, и конфигом она не закрывается.**

Suspend-to-RAM держит мастер-ключ LUKS в памяти. Украденный спящий ноутбук =
расшифрованный диск: ключ достаётся из RAM (cold boot / DMA), а Secure Boot и
TPM тут ни при чём — они защищают загрузку, а система уже загружена.

Варианты:

1. **Поведенческий (работает сразу):** в недоверенной обстановке — полное
   выключение, не крышку закрыть. Ключ уходит из RAM.
2. **Гибернация:** ключ уезжает в шифрованный swap. Сейчас невозможно —
   `swapDevices = []`, своп только zram (`default.nix`: `zramSwap.enable = true`).
   Нужен отдельный swap-раздел внутри LUKS ≥ размера RAM, то есть переразметка
   диска — **отдельная операция, в эту инструкцию не входит**.

Пока не сделан вариант 2, единственная защита — вариант 1.

---

## 4. Обслуживание после включения

| Событие | Что происходит | Что делать |
|---|---|---|
| Обычный `nixos-rebuild switch` | lanzaboote подписывает новый UKI автоматически | ничего |
| Обновление ядра | то же самое | ничего |
| Обновление прошивки UEFI (`fwupd`) | PCR 7 обычно не меняется, но база ключей может быть перезаписана вендором | загрузиться; если просит пароль вместо PIN — перепривязать слот (см. ниже) |
| Сброс/очистка TPM | слот TPM мёртв | войти по паролю LUKS, перепривязать |
| Восстановление с live-USB | Secure Boot заблокирует загрузку с флешки | supervisor-пароль → временно Secure Boot off + USB boot on; после починки вернуть |

Перепривязка слота TPM:

```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes \
  /dev/nvme0n1p2
```

---

## 5. Чего это всё не даёт

Чтобы не было ложного чувства защищённости:

- **Прошивочные импланты.** Перепайка SPI-флешки / программатор на плату —
  не защищает ничего из перечисленного. Против этого работает только физический
  контроль над устройством и пломбы.
- **Работающая система.** Всё вышеописанное — защита периметра загрузки.
  Получивший root на живой машине получает данные.
- **Спящий ноутбук.** См. фазу 7.
- **Принуждение.** Пароль, который можно вспомнить, можно и потребовать.
- **Сеть и приложения.** Ортогонально этой инструкции.

---

## 6. Откат

Полный откат к текущему состоянию (Secure Boot off, systemd-boot, пароль LUKS):

```bash
# 1. Снять слот TPM
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2

# 2. Вернуть конфиг
cd /home/bg/Documents/code/github.com/back2nix/nix/my-nix-config-huawei
git checkout flake.nix devices/yoga14/default.nix
sudo nixos-rebuild boot --flake .#yoga14
```

3. В UEFI: Secure Boot → Disabled (и, при желании, `Restore Factory Keys`).
4. Перезагрузиться. Система вернётся на `systemd-boot` с паролем LUKS.

Порядок важен: сначала снять TPM-слот (пока система грузится), потом менять
загрузчик.

---

## 7. Аварийные ситуации

### Не загружается после фазы 2 (lanzaboote, ещё без ключей)

Причина — конфликт загрузчиков или битый EFI-раздел, не подпись. С live-USB:

```bash
cryptsetup open /dev/nvme0n1p2 cryptroot
mount /dev/mapper/cryptroot /mnt
mount /dev/nvme0n1p1 /mnt/boot
nixos-enter --root /mnt
```

Внутри: проверить, что `loader.systemd-boot.enable = lib.mkForce false` попал в
конфиг (без `mkForce` он конфликтует с `configuration.nix:149`), пересобрать
`nixos-rebuild boot --flake .#yoga14`.

### Чёрный экран / нет вывода после enroll-keys

Симптом отсутствия MS-сертификатов в db (не выполнен `--microsoft`) — не
инициализируются подписанные Intel OpROM. Лечение: в UEFI **Restore Factory
Keys**, загрузиться, повторить 3.4 **с флагом** `--microsoft`.

Если в UEFI не попасть вслепую — Novo-кнопка на боку корпуса при выключенном
питании.

### `Secure Boot: enabled (user)`, но система не грузится

Прошивка отвергает UKI. С live-USB (потребуется временно включить USB boot и
выключить Secure Boot через supervisor-пароль), затем в `nixos-enter`:

```bash
sbctl verify        # что именно не подписано
sbctl sign-all      # подписать
nixos-rebuild boot --flake .#yoga14
```

### Загрузка просит пароль LUKS вместо PIN

Значение PCR 7 изменилось — обновилась прошивка, кто-то трогал Secure Boot, или
атака. **Если сам ничего не обновлял — это сигнал, а не неудобство.** Войти по
паролю, проверить `bootctl status` (должно быть `enabled (user)`) и
`sbctl status`. Если всё чисто — перепривязать слот (раздел 4).

### Забыт PIN

Пароль LUKS остался рабочим (шаг 4.2). Войти по нему, перепривязать слот.

### Забыт supervisor-пароль UEFI

На Lenovo сбрасывается только в сервисе. Система при этом продолжает работать —
недоступны лишь настройки прошивки и загрузка с USB.

---

## 8. Чеклист

```
[ ] 0.2 Бэкап LUKS-заголовка на месте
[ ] 0.3 Live-USB записан и проверен
[ ] 0.4 Конфиг запушен
[ ] 1.1 Supervisor-пароль UEFI задан и записан в двух местах
[ ] 1.3 Thunderbolt security = User Authorization
[ ] 2.1 lanzaboote в inputs; модуль подключён ТОЛЬКО для yoga14 (flake.nix:191)
[ ] 2.2 systemd-boot перебит через lib.mkForce false; pkiBundle=/var/lib/sbctl
[ ] 2.3 Пересборка прошла, система ПЕРЕЗАГРУЗИЛАСЬ (SB ещё off)
[ ] 3.1 UEFI в Setup Mode, sbctl status подтверждает
[ ] 3.2 sbctl create-keys
[ ] 3.3 sbctl verify: /boot/EFI/Linux/* и BOOTX64.EFI подписаны
[ ] 3.4 sbctl enroll-keys --microsoft  (флаг обязателен!)
[ ] 3.5 Secure Boot включён в UEFI
[ ] 3.6 bootctl status: Secure Boot: enabled (user)
[ ] 3.7 КЛЮЧИ /var/lib/sbctl СОХРАНЕНЫ В ДВУХ МЕСТАХ ВНЕ НОУТБУКА
[ ] 4.1 initrd.systemd.enable = true; загрузка с паролем проверена
[ ] 4.2 systemd-cryptenroll --tpm2-pcrs=7 --tpm2-with-pin=yes
[ ] 4.2 Парольный слот НЕ удалён (luksDump показывает два слота)
[ ] 4.3 Загрузка по PIN работает; запасной ввод пароля работает
[ ] 5   USB Boot и Network Boot отключены в UEFI
[ ] 6   (опц.) lockdown=integrity + efi=disable_early_pci_dma, камера проверена
[ ] 7   (опц./поведенческое) в поездках — выключение, не suspend
```
