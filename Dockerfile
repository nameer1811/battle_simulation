FROM eclipse-temurin:17-jdk-jammy

ARG NETLOGO_VERSION=7.0.3
ARG NETLOGO_ARCHIVE=NetLogo-${NETLOGO_VERSION}-64.tgz

ENV APP_HOME=/app \
    NETLOGO_HOME="/opt/NetLogo ${NETLOGO_VERSION}" \
    MODEL_FILE=/app/build/san_jacinto_battle_headless.nlogox \
    OUTPUT_DIR=/app/output \
    OUTPUT_FILE=/app/output/batch-results.csv \
    RUNS=50 \
    MEXICAN_CONCENTRATION=100 \
    COS_FATIGUE=100 \
    TIME_LIMIT_STEPS=600 \
    NETLOGO_THREADS=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tar bash python3 python3-pip \
    && pip3 install --no-cache-dir pandas matplotlib seaborn \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -L "https://github.com/NetLogo/NetLogo/releases/download/v${NETLOGO_VERSION}/${NETLOGO_ARCHIVE}" -o /tmp/netlogo.tgz \
    && tar -xzf /tmp/netlogo.tgz -C /opt \
    && rm /tmp/netlogo.tgz

COPY models /app/models
COPY src /app/src
COPY scripts /app/scripts

RUN sed -i 's/\r//' /app/scripts/*.sh \
    && chmod +x /app/scripts/*.sh \
    && mkdir -p /app/build/classes /app/output \
    && sed '/<experiments>/,/<\/experiments>/d' /app/models/san_jacinto_battle.nlogox > /app/build/san_jacinto_battle_headless.nlogox \
    && javac -cp "/opt/NetLogo 7.0.3/lib/app/netlogo-7.0.3.jar" -d /app/build/classes /app/src/BatchRunner.java

ENTRYPOINT ["/app/scripts/run-batch-parallel.sh"]
