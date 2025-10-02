#!/bin/bash

# Ejemplo de crontab para ejecutar cada 10 minutos:
# */10 * * * * /ruta/ddns_ipv4.sh >> /var/log/ddns_ipv4.log 2>&1

# ===== CONFIGURACIÓN =====
ZONE_ID=
CLOUDFLARE_EMAIL=
CLOUDFLARE_API_KEY=
DOMAIN_NAME=   # Dominio que quieres actualizar

# ===== OBTENER ID DEL REGISTRO IPV4 =====
records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")

DNS4_RECORD_ID=$(echo "$records" | jq -r '.result[] | select(.name=="'"$DOMAIN_NAME"'" and .type=="A") | .id')

# ===== OBTENER IP PÚBLICA IPV4 =====
ipv4_check=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip' | sed 's/ip=//')

# ===== COMPARAR Y ACTUALIZAR =====
if [ -n "$DNS4_RECORD_ID" ]; then
    ipv4_current=$(curl -s https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS4_RECORD_ID \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        | jq -r '.result.content')

    if [ "$ipv4_current" != "$ipv4_check" ]; then
        echo "IPv4 cambiado: $ipv4_current → $ipv4_check"
        curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS4_RECORD_ID" \
            -H "Content-Type: application/json" \
            -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            --data '{
              "content": "'"$ipv4_check"'",
              "name": "'"$DOMAIN_NAME"'",
              "proxied": true,
              "ttl": 3600,
              "type": "A"
            }' | jq '.success'
    else
        echo "IPv4 no cambió ($ipv4_check)"
    fi
fi

# ===== REGISTRO =====
echo "Última ejecución: $(date '+%d/%m/%Y %H:%M:%S')"

