#!/bin/sh
set -e

# -------------------------------------------------------------------
# perftestServerCompress.sh
# Serveur TLS/QUIC avec option compression certificat (RFC 8879)
# -------------------------------------------------------------------

if [ -z "$TC_DELAY" ]; then TC_DELAY=0ms; fi
if [ -z "$TC_LOSS" ]; then TC_LOSS="0%"; fi
if [ -z "$USE_TLS" ]; then USE_TLS="true"; fi
if [ -z "$CERT_PATH" ]; then export CERT_PATH=/cert; fi
if [ -z "$COMPRESS_CERT" ]; then COMPRESS_CERT="false"; fi

INTERFAZ="lo"
echo "[SERVER] netem on $INTERFAZ..."
tc qdisc add dev "$INTERFAZ" root netem delay $TC_DELAY loss $TC_LOSS 2>/dev/null || true

if [ -z "$KEM_ALG" ]; then KEM_ALG=mlkem512; fi
export DEFAULT_GROUPS=$KEM_ALG
if [ -z "$SIG_ALG" ]; then export SIG_ALG=mldsa44; fi

echo "[SERVER] SIG=$SIG_ALG KEM=$KEM_ALG COMPRESS=$COMPRESS_CERT PROTO=$([ "$USE_TLS" = "true" ] && echo TLS || echo QUIC)"

if [ "$USE_TLS" = "true" ]; then
    if [ "$COMPRESS_CERT" = "true" ]; then
        echo "[SERVER] Starting TLS with certificate compression..."
        openssl s_server -cert "$CERT_PATH/server.crt" -key "$CERT_PATH/server.key" \
            -groups "$DEFAULT_GROUPS" -www -tls1_3 -accept :4433 \
            -compress_cert &
    else
        echo "[SERVER] Starting TLS without certificate compression..."
        openssl s_server -cert "$CERT_PATH/server.crt" -key "$CERT_PATH/server.key" \
            -groups "$DEFAULT_GROUPS" -www -tls1_3 -accept :4433 &
    fi
else
    echo "[SERVER] Starting QUIC server..."
    quics_server -groups:"$DEFAULT_GROUPS" \
        -cert_file:"$CERT_PATH/server.crt" -key_file:"$CERT_PATH/server.key" &
fi

sleep 2
echo "[SERVER] Ready."

# Keep alive
wait
