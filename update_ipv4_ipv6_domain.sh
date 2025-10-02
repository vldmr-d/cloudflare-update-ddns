#!/bin/bash

# Ejemplo de entrada en crontab para que se ejecute cada 10 minutos:
# */10 * * * * /ruta/script_ddns.sh >> /var/log/ddns.log 2>&1

# ===== CONFIGURACIÓN =====
ZONE_ID=
CLOUDFLARE_EMAIL=
CLOUDFLARE_API_KEY=
DOMAIN_NAME=   # Dominio que quieres actualizar

# ===== OBTENER IDS AUTOMÁTICAMENTE =====
records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")

DNS4_RECORD_ID=$(echo "$records" | jq -r '.result[] | select(.name=="'"$DOMAIN_NAME"'" and .type=="A") | .id')
DNS6_RECORD_ID=$(echo "$records" | jq -r '.result[] | select(.name=="'"$DOMAIN_NAME"'" and .type=="AAAA") | .id')

# ===== OBTENER IP PÚBLICA =====
ipv4_check=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip' | sed 's/ip=//')
ipv6_check=$(curl -s -6 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip' | sed 's/ip=//')

# ===== FUNCIONES AUXILIARES =====
update_dns_record() {
    local type=$1
    local record_id=$2
    local new_ip=$3

    if [ -n "$record_id" ]; then
        current_ip=$(curl -s https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id \
            -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            | jq -r '.result.content')

        if [ "$current_ip" != "$new_ip" ]; then
            echo "$type cambiado: $current_ip → $new_ip"
            curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
                -H "Content-Type: application/json" \
                -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
                -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                --data '{
                  "content": "'"$new_ip"'",
                  "name": "'"$DOMAIN_NAME"'",
                  "proxied": true,
                  "ttl": 3600,
                  "type": "'"$type"'"
                }' | jq '.success'
        else
            echo "$type no cambió ($new_ip)"
        fi
    fi
}

# ===== ACTUALIZAR IPV4 =====
update_dns_record "A" "$DNS4_RECORD_ID" "$ipv4_check"

# ===== ACTUALIZAR IPV6 =====
update_dns_record "AAAA" "$DNS6_RECORD_ID" "$ipv6_check"

# ===== REGISTRO =====
echo "Última ejecución: $(date '+%d/%m/%Y %H:%M:%S')"

