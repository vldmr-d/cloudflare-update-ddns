#!/bin/bash

# Ejemplo de crontab para ejecutar cada 10 minutos:
# */10 * * * * /ruta/ddns_ipv6.sh >> /var/log/ddns_ipv6.log 2>&1

# ===== CONFIGURACIÓN =====
ZONE_ID=
CLOUDFLARE_EMAIL=
CLOUDFLARE_API_KEY=
DOMAIN_NAME=   # Dominio que quieres actualizar

# ===== OBTENER ID DEL REGISTRO IPV6 =====
records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")

DNS6_RECORD_ID=$(echo "$records" | jq -r '.result[] | select(.name=="'"$DOMAIN_NAME"'" and .type=="AAAA") | .id')

# ===== OBTENER IP PÚBLICA IPV6 =====
ipv6_check=$(curl -s -6 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip' | sed 's/ip=//')

# ===== COMPARAR Y ACTUALIZAR =====
if [ -n "$DNS6_RECORD_ID" ]; then
    ipv6_current=$(curl -s https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS6_RECORD_ID \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        | jq -r '.result.content')

    if [ "$ipv6_current" != "$ipv6_check" ]; then
        echo "IPv6 cambiado: $ipv6_current → $ipv6_check"
        curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS6_RECORD_ID" \
            -H "Content-Type: application/json" \
            -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            --data '{
              "content": "'"$ipv6_check"'",
              "name": "'"$DOMAIN_NAME"'",
              "proxied": true,
              "ttl": 3600,
              "type": "AAAA"
            }' | jq '.success'
    else
        echo "IPv6 no cambió ($ipv6_check)"
    fi
fi

# ===== REGISTRO =====
echo "Última ejecución: $(date '+%d/%m/%Y %H:%M:%S')"

