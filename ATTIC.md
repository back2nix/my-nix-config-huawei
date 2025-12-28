# Attic

```bash
sudo systemctl status atticd.service

● atticd.service - Attic Binary Cache Server
     Loaded: loaded (/etc/systemd/system/atticd.service; enabled; preset: ignored)
     Active: active (running) since Sun 2025-12-28 16:32:36 MSK; 12min ago
 Invocation: e1b861c9e41d414eaead4d7dd9f9beb6
   Main PID: 286235 (atticd)
         IP: 1.4K in, 912B out
         IO: 300K read, 60K written
      Tasks: 10 (limit: 37881)
     Memory: 3.5M (peak: 4.8M)
        CPU: 39ms
     CGroup: /system.slice/atticd.service
             └─286235 /nix/store/lkyl93ljwfy2kfkkklmqi17vnpd5395k-attic-0-unstable-2025-09-24/bin/atticd --config /nix/store/siy2bb26nzxd9wf0b9g0wmjfih6yl573-attic.toml

дек 28 16:32:36 yoga14 systemd[1]: Started Attic Binary Cache Server.
дек 28 16:32:36 yoga14 mq6spslnv0wazhh298ph82558lsmash9-attic-run[286235]: Attic Server 0.1.0 (release)
дек 28 16:32:36 yoga14 mq6spslnv0wazhh298ph82558lsmash9-attic-run[286235]: Running migrations...
дек 28 16:32:36 yoga14 mq6spslnv0wazhh298ph82558lsmash9-attic-run[286235]: Starting API server...
дек 28 16:32:36 yoga14 mq6spslnv0wazhh298ph82558lsmash9-attic-run[286235]: Listening on [::]:8080...
```

```bash
# 1. Переходим в root и запускаем bash (чтобы source сработал корректно)
sudo -i
bash

# 2. Экспортируем переменную с секретом
set -a
source /run/secrets/attic/env
set +a

# 3. Генерируем токен.
# ОБЯЗАТЕЛЬНО добавляем флаг --config с путем, который был в systemctl status
atticadm make-token \
  --config "/nix/store/siy2bb26nzxd9wf0b9g0wmjfih6yl573-attic.toml" \
  --sub "admin" \
  --validity "10y" \
  --pull "*" \
  --push "*" \
  --create-cache "*" \
  --configure-cache "*" \
  --destroy-cache "*" > /tmp/token.txt

# 4. Проверяем, что токен создался
cat /tmp/token.txt

# 5. Выходим из bash и root
exit
exit
```


```bash
# 2. Логинимся клиентом (используем токен из файла)
attic login local http://127.0.0.1:8080 $(sudo cat /tmp/token.txt)

# 3. Создаем кэш с именем "system"
attic cache create system

# 4. Узнаем Публичный Ключ
attic cache info system
```
