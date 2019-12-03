#!/bin/bash

WORK_DIR="/root"
INDEX_FILE="/root/index.html"
INDEX_SHA1SUM_FILE=$INDEX_FILE".sha1sum"
LOG_PATH="/var/log/script1.log"

SERVER_LIST=(46.101.99.44 142.93.163.100)
SERVER_DIR=(siteiki sitebir)

log () {
        echo "$(date) [$$] $1"
}

deploy () {
        SERVER=$1
        FILE_PATH=$2

        log "Dosyanin eski HASH degeri: $(cat $INDEX_SHA1SUM_FILE)"
        sha1sum $INDEX_FILE > $INDEX_SHA1SUM_FILE
        log "Dosyanin yeni HASH degeri: $(cat $INDEX_SHA1SUM_FILE)"

        log "HAProxy config. dosyasinin yedegi aliniyor."
        cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.yedek

        log "Birinci node LBda devreden cikariliyor."
        sed -i 's/^.*$SERVER/#server www01 $SERVER/' /etc/haproxy/haproxy.cfg

        log "LB reload ediliyor."
        /etc/init.d/haproxy reload
        log "LB reload edildi."

        log "Birinci node icin RSYNC baslatiliyor."
        rsync -av $INDEX_FILE root@$SERVER:/var/www/html/$FILE_PATH/index.html
        log "Birinci node icin RSYNC tamamlandı."

        log "Birinci node tekrar LBda devreye aliniyor."
        sed -i 's/^#server/server/' /etc/haproxy/haproxy.cfg

        log "LB reload ediliyor."
        /etc/init.d/haproxy reload
        log "LB reload edildi."
}

cd $WORK_DIR

test -f $INDEX_SHA1SUM_FILE || {
        log "$INDEX_SHA1SUM_FILE dosyasi olusturuluyor..."
        sha1sum $INDEX_FILE > $INDEX_SHA1SUM_FILE
}

sha1sum --status -c $INDEX_SHA1SUM_FILE && {
                log "Hash ve dosya ayni, degistirmiyorum."
                exit 69
        }

log "Dosyada degisiklik olmus, surum cikiyoruz."

N=$((${#SERVER_LIST[@]} - 1)) # 2 - 1 = 1
for i in $(seq 0 $N); do # 0 dan 1 e kadar döngüye sokacak
        deploy "${SERVER_LIST[$i]}" "${SERVER_DIR[$i]}"
done

log "ISLEM BASARIYLA TAMAMLANDI"
