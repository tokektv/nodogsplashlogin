#!/bin/sh

# Voucher Validation Script - MULTIPLE USE ENABLED
VOUCHER_FILE="/etc/nodogsplash/voucher/voucher.txt"
LOG_FILE="/tmp/voucher_auth.log"
MAX_DURATION=180    # 3 jam maksimal

# Parameters dari UCI: $1=auth_client, $2=client_mac, $3=username, $4=password
ACTION="$1"
CLIENT_MAC="$2"
USERNAME="$3"
PASSWORD="$4"

if [ "$ACTION" = "auth_client" ]; then
    echo "$(date): Auth attempt - MAC: $CLIENT_MAC, Voucher: $USERNAME" >> $LOG_FILE

    # Cek file voucher
    if [ ! -f "$VOUCHER_FILE" ]; then
        echo "0"
        exit 1
    fi

    # Validasi voucher
    while IFS='|' read -r code duration status; do
        if [ "$code" = "$USERNAME" ] && [ "$status" = "active" ]; then
            
            # Pastikan durasi tidak melebihi 3 jam
            if [ "$duration" -gt "$MAX_DURATION" ]; then
                duration="$MAX_DURATION"
            fi
            
            echo "$(date): SUCCESS - Voucher $code ($duration menit) for $CLIENT_MAC" >> $LOG_FILE
            
            # âš ï¸ LINE INI DIHAPUS/DI-COMMENT:
            # JANGAN mark as used - biarkan active untuk multiple use
            # sed -i "s/^$code|$duration|active$/$code|$duration|used/g" "$VOUCHER_FILE"
            
            # Return duration in seconds
            DURATION_SECONDS=$((duration * 60))
            echo "$DURATION_SECONDS"
            exit 0
        fi
    done < "$VOUCHER_FILE"

    # Voucher tidak valid
    echo "$(date): FAILED - Invalid voucher: $USERNAME" >> $LOG_FILE
    echo "0"
    exit 1
else
    # Handle deauth events
    echo "$(date): Deauth - Action: $ACTION, MAC: $CLIENT_MAC" >> $LOG_FILE
    exit 0
fi
