#!/bin/bash
# ssh-auto-authorize.sh — Detecta equipos del consejo online y configura SSH bidireccional
# Ejecutar desde el Mac Mini. Genera claves en equipos remotos que no tengan y las autoriza aquí.
# Uso: bash ops/ssh-auto-authorize.sh
#      bash ops/ssh-auto-authorize.sh --watch   (bucle cada 60s hasta completar todos)

SSH_OPTS="-o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes -i $HOME/.ssh/id_ed25519"
AUTH_FILE="$HOME/.ssh/authorized_keys"
MACMINI_PUB=$(cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null)

# Equipos del consejo pendientes de configurar
HOSTS=(MacBookAirPlata   MacBookAirAzul   MacBookAirCrema   MacBookAir16   MacBookProNegro14   MacBookAirBlanco)
IPS=(  100.114.113.88    100.84.81.45     100.110.80.2      100.99.176.126 100.101.192.1       100.75.118.75)
TAGS=( Plata-council     Azul-council     Crema-council     Air16-council  ProNegro14-council  Blanco-council)

authorize_one() {
    local host="$1" ip="$2" tag="$3"

    # 1. Verificar que el equipo responde por SSH
    if ! ssh $SSH_OPTS csilvasantin@"$ip" "echo ok" &>/dev/null; then
        echo "  $host ($ip): OFFLINE"
        return 1
    fi

    # 2. Verificar si ya puede hacer SSH inverso al Mac Mini
    CAN_REACH=$(ssh $SSH_OPTS csilvasantin@"$ip" \
        "ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes csilvasantin@100.74.101.14 'echo REACHABLE' 2>/dev/null" 2>/dev/null)
    if [ "$CAN_REACH" = "REACHABLE" ]; then
        echo "  $host ($ip): YA CONFIGURADO ✓"
        return 0
    fi

    echo "  $host ($ip): Configurando SSH bidireccional..."

    # 3. Generar clave en el equipo remoto si no tiene
    ssh $SSH_OPTS csilvasantin@"$ip" \
        "test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C '$tag'" 2>/dev/null

    # 4. Leer la clave pública del equipo remoto
    PUBKEY=$(ssh $SSH_OPTS csilvasantin@"$ip" "cat ~/.ssh/id_ed25519.pub" 2>/dev/null)
    if [ -z "$PUBKEY" ]; then
        echo "  $host ($ip): ERROR — no se pudo leer clave pública"
        return 1
    fi

    # 5. Añadir al authorized_keys del Mac Mini si no está
    if ! grep -qF "$PUBKEY" "$AUTH_FILE" 2>/dev/null; then
        echo "$PUBKEY" >> "$AUTH_FILE"
        echo "  $host ($ip): Clave añadida al Mac Mini ✓"
    else
        echo "  $host ($ip): Clave ya estaba en Mac Mini"
    fi

    # 6. Asegurar que la clave del Mac Mini está en el equipo remoto
    if [ -n "$MACMINI_PUB" ]; then
        ssh $SSH_OPTS csilvasantin@"$ip" \
            "grep -qF '$MACMINI_PUB' ~/.ssh/authorized_keys 2>/dev/null || echo '$MACMINI_PUB' >> ~/.ssh/authorized_keys" 2>/dev/null
    fi

    # 7. Desactivar Tailscale SSH (intercepta conexiones y abre browsers de login)
    ssh $SSH_OPTS csilvasantin@"$ip" \
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale set --ssh=false 2>/dev/null" 2>/dev/null
    echo "  $host ($ip): Tailscale SSH desactivado ✓"

    # 8. Verificar conexión bidireccional
    VERIFY=$(ssh $SSH_OPTS csilvasantin@"$ip" \
        "ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes csilvasantin@100.74.101.14 'echo OK' 2>/dev/null" 2>/dev/null)
    if [ "$VERIFY" = "OK" ]; then
        echo "  $host ($ip): SSH BIDIRECCIONAL OK ✓✓"
        return 0
    else
        echo "  $host ($ip): SSH ida OK, vuelta pendiente (puede necesitar aceptar host key manualmente)"
        return 0
    fi
}

run_once() {
    echo "=== SSH Auto-Authorize — Consejo AdmiraNext ==="
    echo "Mac Mini IP: 100.74.101.14"
    echo ""
    local pending=0
    for i in "${!HOSTS[@]}"; do
        authorize_one "${HOSTS[$i]}" "${IPS[$i]}" "${TAGS[$i]}" || ((pending++))
    done
    echo ""
    echo "Pendientes: $pending"
    return $pending
}

if [ "$1" = "--watch" ]; then
    echo "Modo vigilancia: comprobando cada 60s hasta que todos estén configurados..."
    echo ""
    while true; do
        run_once
        pending=$?
        if [ $pending -eq 0 ]; then
            echo ""
            echo "¡Todos los equipos del consejo configurados!"
            break
        fi
        echo "Esperando 60s para reintentar ($pending pendientes)..."
        sleep 60
    done
else
    run_once
fi
