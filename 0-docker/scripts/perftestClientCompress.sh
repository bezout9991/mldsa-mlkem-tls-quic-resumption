#!/bin/sh
set -e

# -------------------------------------------------------------------
# perftestClientCompress.sh
# Client TLS/QUIC avec/sans compression certificat + capture pcap
#
# Capture le trafic avec tcpdump pour mesurer:
#   - taille totale du handshake (bytes)
#   - nombre de paquets
#   - retransmissions
# -------------------------------------------------------------------

if [ -z "$TC_DELAY" ]; then TC_DELAY=0ms; fi
if [ -z "$TC_LOSS" ]; then TC_LOSS="0%"; fi
if [ -z "$DOCKER_HOST" ]; then DOCKER_HOST="localhost"; fi
if [ -z "$USE_TLS" ]; then USE_TLS="true"; fi
if [ -z "$NUM_RUNS" ]; then NUM_RUNS=500; fi
if [ -z "$CERT_PATH" ]; then export CERT_PATH=/cert; fi
if [ -z "$MUTUAL" ]; then MUTUAL="false"; fi
if [ -z "$COMPRESS_CERT" ]; then COMPRESS_CERT="false"; fi
if [ -z "$CLIENT_ID" ]; then CLIENT_ID=0; fi
if [ -z "$RESULTS_DIR" ]; then RESULTS_DIR=/results; fi

INTERFAZ="lo"
echo "[client-$CLIENT_ID] netem on $INTERFAZ..."
tc qdisc add dev "$INTERFAZ" root netem delay $TC_DELAY loss $TC_LOSS 2>/dev/null || true

if [ -z "$KEM_ALG" ]; then KEM_ALG=mlkem512; fi
export DEFAULT_GROUPS=$KEM_ALG
if [ -z "$SIG_ALG" ]; then export SIG_ALG=mldsa44; fi

COMPRESS_LABEL=$([ "$COMPRESS_CERT" = "true" ] && echo "compressed" || echo "nocompress")
echo "[client-$CLIENT_ID] SIG=$SIG_ALG KEM=$KEM_ALG COMPRESS=$COMPRESS_LABEL PROTO=$([ "$USE_TLS" = "true" ] && echo TLS || echo QUIC)"

mkdir -p "$RESULTS_DIR"

# Fichier CSV résultats
CSV_FILE="${RESULTS_DIR}/compress_${CLIENT_ID}_${SIG_ALG}_${KEM_ALG}_${COMPRESS_LABEL}.csv"
echo "run_id,duration_ms,success" > "$CSV_FILE"

# Fichier pcap
PCAP_FILE="${RESULTS_DIR}/capture_${CLIENT_ID}_${SIG_ALG}_${KEM_ALG}_${COMPRESS_LABEL}.pcap"

# Démarrer tcpdump en arrière-plan
echo "[client-$CLIENT_ID] Starting tcpdump..."
tcpdump -i "$INTERFAZ" -w "$PCAP_FILE" -s 0 \
    "host $DOCKER_HOST and (port 4433 or port 443)" &
TCPDUMP_PID=$!
sleep 1

# -------------------------------------------------------------------
# Exécution des handshakes
# -------------------------------------------------------------------
i=1
while [ $i -le $NUM_RUNS ]; do
    START_TIME=$(date +%s%3N)

    if [ "$USE_TLS" = "true" ]; then
        if [ "$COMPRESS_CERT" = "true" ]; then
            if [ "$MUTUAL" = "true" ]; then
                OUTPUT=$(openssl s_connection -connect "$DOCKER_HOST:4433" -new \
                    -verify 1 -CAfile "$CERT_PATH/CA.crt" \
                    -cert "$CERT_PATH/user.crt" -key "$CERT_PATH/user.key" \
                    -compress_cert 2>&1)
            else
                OUTPUT=$(openssl s_connection -connect "$DOCKER_HOST:4433" -new \
                    -verify 1 -CAfile "$CERT_PATH/CA.crt" \
                    -compress_cert 2>&1)
            fi
        else
            if [ "$MUTUAL" = "true" ]; then
                OUTPUT=$(openssl s_connection -connect "$DOCKER_HOST:4433" -new \
                    -verify 1 -CAfile "$CERT_PATH/CA.crt" \
                    -cert "$CERT_PATH/user.crt" -key "$CERT_PATH/user.key" 2>&1)
            else
                OUTPUT=$(openssl s_connection -connect "$DOCKER_HOST:4433" -new \
                    -verify 1 -CAfile "$CERT_PATH/CA.crt" 2>&1)
            fi
        fi
    else
        if [ -n "${SSL_DIR:-}" ]; then
            mkdir -p "$SSL_DIR"
            export SSLKEYLOGFILE="${SSL_DIR}/sslkeys_compress_${CLIENT_ID}_${SIG_ALG}_${KEM_ALG}.log"
        fi
        if [ "$MUTUAL" = "true" ]; then
            OUTPUT=$(quics_connection -groups:"$KEM_ALG" -target:"$DOCKER_HOST" \
                -CAfile:"$CERT_PATH/CA.crt" \
                -cert "$CERT_PATH/user.crt" -key "$CERT_PATH/user.key" 2>&1)
        else
            OUTPUT=$(quics_connection -groups:"$KEM_ALG" -target:"$DOCKER_HOST" \
                -CAfile:"$CERT_PATH/CA.crt" 2>&1)
        fi
    fi

    END_TIME=$(date +%s%3N)
    DURATION=$((END_TIME - START_TIME))

    if echo "$OUTPUT" | grep -q "Handshake duration"; then
        HS_DURATION=$(echo "$OUTPUT" | grep "Handshake duration" | grep -oE '[0-9.]+')
        echo "$i,$HS_DURATION,1" >> "$CSV_FILE"
    elif echo "$OUTPUT" | grep -qi "error\|failed\|abort"; then
        echo "$i,$DURATION,0" >> "$CSV_FILE"
    else
        echo "$i,$DURATION,1" >> "$CSV_FILE"
    fi

    i=$((i + 1))
done

# Arrêter tcpdump
echo "[client-$CLIENT_ID] Stopping tcpdump..."
sleep 1
kill "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" 2>/dev/null || true

echo "[client-$CLIENT_ID] Done. CSV: $CSV_FILE  PCAP: $PCAP_FILE"
