#! /usr/bin/env bash

# Путь к файлу конфигурации
config_file="vpn.conf"

# Путь к файлу шаблона
template_file="vpn.template"

# Проверка наличия файлов
if [ ! -f "$config_file" ]; then
	echo "Файл конфигурации не найден: $config_file"
	exit 1
fi

if [ ! -f "$template_file" ]; then
	echo "Файл шаблона не найден: $template_file"
	exit 1
fi

# Извлечение переменных из файла конфигурации
interface_private_key=$(awk '/^PrivateKey/{print $3}' "$config_file")
interface_address=$(awk '/^Address/{print $3}' "$config_file")
interface_dns=$(awk '/^DNS/{print $3}' "$config_file")
peer_public_key=$(awk '/^PublicKey/{print $3}' "$config_file")
peer_preshared_key=$(awk '/^PresharedKey/{print $3}' "$config_file")
peer_allowed_ips=$(awk '/^AllowedIPs/{print $3}' "$config_file" | sed 's/,//g' | sed -e 's/^/"/' -e 's/$/"/' | tr '\n' ' ')
peer_persistent_keepalive=$(awk '/^PersistentKeepalive/{print $3}' "$config_file")
peer_endpoint=$(awk '/^Endpoint/{print $3}' "$config_file")

echo "$peer_preshared_key" >presharedKeyFile
echo "$interface_private_key" >private

# Замена переменных в шаблоне
sed -e "s|setPrivateKey|${interface_private_key}|g" \
	-e "s|setAddress|${interface_address}|g" \
	-e "s|setDNS|${interface_dns}|g" \
	-e "s|setPublicKey|${peer_public_key}|g" \
	-e "s|setPresharedKeyFile|${peer_preshared_key}|g" \
	-e "s|setAllowedIPs|${peer_allowed_ips}|g" \
	-e "s|setEndpoint|${peer_endpoint}|g" \
	-e "s|setPersistentKeepalive|${peer_persistent_keepalive}|g" \
	"$template_file" >vpn.nix
