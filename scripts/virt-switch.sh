#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "❌ Запускай через sudo!"
  exit 1
fi

MODE=$1

case $MODE in
  kvm)
    echo "🔄 Переключаюсь на KVM (QEMU)..."

    # 1. Глушим VirtualBox
    echo "   Stopping VirtualBox services..."
    pkill -f VirtualBox 2>/dev/null || true
    pkill -f VBox 2>/dev/null || true

    # 2. Выгружаем модули VirtualBox (порядок важен!)
    modprobe -r vboxnetadp 2>/dev/null || true
    modprobe -r vboxnetflt 2>/dev/null || true
    modprobe -r vboxdrv 2>/dev/null

    if lsmod | grep -q "vboxdrv"; then
       echo "❌ Ошибка: Не удалось выгрузить vboxdrv. Проверь, не запущены ли виртуалки."
       exit 1
    fi

    # 3. Загружаем KVM
    echo "   Loading KVM modules..."
    modprobe kvm
    modprobe kvm_intel

    # 4. Стартуем libvirtd
    echo "   Starting libvirtd..."
    # systemctl start libvirtd

    echo "✅ Готово! KVM активен."
    ;;

  vbox)
    echo "🔄 Переключаюсь на VirtualBox..."

    # 1. Глушим KVM/Libvirt
    echo "   Stopping libvirtd..."
    # systemctl stop libvirtd
    # systemctl stop libvirtd.socket 2>/dev/null || true
    # На всякий случай убиваем qemu, если висит
    pkill -f qemu-system 2>/dev/null || true

    # 2. Выгружаем модули KVM
    echo "   Unloading KVM modules..."
    modprobe -r kvm_intel 2>/dev/null || true
    modprobe -r kvm 2>/dev/null

    if lsmod | grep -q "kvm"; then
       echo "❌ Ошибка: Не удалось выгрузить kvm. Возможно, что-то держит модуль."
       exit 1
    fi

    # 3. Загружаем VirtualBox
    echo "   Loading VirtualBox modules..."
    modprobe vboxdrv
    modprobe vboxnetflt
    modprobe vboxnetadp

    echo "✅ Готово! VirtualBox активен."
    ;;

  status)
    echo "📊 Текущий статус модулей:"
    echo "--- KVM ---"
    lsmod | grep kvm
    echo "--- VirtualBox ---"
    lsmod | grep vbox
    ;;

  *)
    echo "Использование: sudo virt-switch [kvm | vbox | status]"
    exit 1
    ;;
esac
