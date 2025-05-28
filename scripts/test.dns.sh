#!/usr/bin/env fish

# Проверка зашифрованного DNS в NixOS
echo "🔍 Проверка статуса зашифрованного DNS..."
echo "=================================================="

# 1. Проверка статуса systemd-resolved
echo -e "\n📊 Статус systemd-resolved:"
systemctl status systemd-resolved --no-pager -l 2>/dev/null || echo "❌ Не удалось получить статус resolved"

# 2. Проверка текущих DNS настроек
echo -e "\n🌐 Текущие DNS настройки:"
resolvectl status 2>/dev/null || echo "❌ resolvectl недоступен"

# 3. Проверка DoT соединений
echo -e "\n🔒 Проверка DoT соединений:"
resolvectl query cloudflare-dns.com --type=A 2>/dev/null || echo "❌ Не удалось выполнить DoT запрос"

# 4. Анализ активных соединений на порт 853 (DoT)
echo -e "\n🔌 Активные DoT соединения (порт 853):"
ss -tuln | grep :853 2>/dev/null || echo "❌ Нет активных DoT соединений"
netstat -tulpn 2>/dev/null | grep :853 || echo "❌ netstat не показывает DoT соединения"

# 5. Проверка конфигурации resolved
echo -e "\n⚙️ Конфигурация resolved:"
cat /etc/systemd/resolved.conf 2>/dev/null || echo "❌ Не удалось прочитать конфиг resolved"

# 6. Тест DNS запроса с подробностями
echo -e "\n🧪 Тестовый DNS запрос:"
dig @1.1.1.1 example.com +short 2>/dev/null || echo "❌ dig недоступен"
nslookup example.com 2>/dev/null || echo "❌ nslookup недоступен"

# 7. Проверка DNS через resolved
echo -e "\n🔍 DNS через systemd-resolved:"
resolvectl query example.com 2>/dev/null || echo "❌ Не удалось выполнить запрос через resolved"

# 8. Анализ сетевого трафика (кратковременный)
echo -e "\n📈 Статистика resolved:"
sudo resolvectl statistics 2>/dev/null || echo "❌ Статистика недоступна"

# 9. Проверка, какой DNS сервер отвечает
echo -e "\n🌍 Определение DNS провайдера:"
dig TXT o-o.myaddr.l.google.com @resolver1.opendns.com +short 2>/dev/null || echo "❌ Не удалось определить провайдера"

# 10. Проверка DNS утечек через curl
echo -e "\n💧 Проверка DNS утечек:"
curl -s "https://1.1.1.1/cdn-cgi/trace" 2>/dev/null | grep -E "(ip=|loc=)" || echo "❌ Не удалось проверить утечки через Cloudflare"

# 11. Статистика resolved
echo -e "\n📡 Анализ DNS трафика (5 секунд):"
if command -v tcpdump > /dev/null 2>&1
    echo "Запуск tcpdump для анализа DNS трафика..."
    timeout 5s sudo tcpdump -i any port 53 or port 853 -c 10 2>/dev/null || echo "❌ Не удалось захватить трафик"
else
    echo "❌ tcpdump недоступен"
end

# 12. Проверка журналов resolved
echo -e "\n📝 Последние записи resolved (последние 10):"
journalctl -u systemd-resolved --no-pager -n 10 2>/dev/null || echo "❌ Не удалось прочитать журналы"

# 13. Проверка DoT через openssl
echo -e "\n🔐 Тест DoT соединения через openssl:"
echo | timeout 5s openssl s_client -connect 1.1.1.1:853 -servername cloudflare-dns.com 2>/dev/null | grep -E "(CONNECTED|Verify return code)" || echo "❌ DoT соединение через openssl не установлено"

# 14. Проверка текущего DNS сервера
echo -e "\n🎯 Текущий используемый DNS:"
cat /etc/resolv.conf 2>/dev/null || echo "❌ Не удалось прочитать resolv.conf"

echo -e "\n✅ Проверка завершена!"
echo "=================================================="
echo "💡 Если вы видите DoT соединения на порту 853 и"
echo "   resolved показывает зашифрованные серверы, то"
echo "   ваш DNS трафик зашифрован."
