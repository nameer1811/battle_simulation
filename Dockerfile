FROM eclipse-temurin:17-jdk-jammy

ARG NETLOGO_VERSION=7.0.3
ARG NETLOGO_ARCHIVE=NetLogo-${NETLOGO_VERSION}-64.tgz

ENV APP_HOME=/app \
    NETLOGO_HOME="/opt/NetLogo ${NETLOGO_VERSION}" \
    MODEL_FILE=/app/final_model_v2_headless.nlogox \
    OUTPUT_DIR=/app/output \
    OUTPUT_FILE=/app/output/batch-results.csv \
    RUNS=50 \
    MEXICAN_CONCENTRATION=100 \
    COS_FATIGUE=100 \
    TIME_LIMIT_STEPS=600 \
    NETLOGO_THREADS=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tar bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -L "https://github.com/NetLogo/NetLogo/releases/download/v${NETLOGO_VERSION}/${NETLOGO_ARCHIVE}" -o /tmp/netlogo.tgz \
    && tar -xzf /tmp/netlogo.tgz -C /opt \
    && rm /tmp/netlogo.tgz

COPY final_model_v2.nlogox /app/final_model_v2.nlogox
COPY BatchRunner.java /app/BatchRunner.java
COPY run-batch-sim.sh /app/run-batch-sim.sh
COPY run-batch-parallel.sh /app/run-batch-parallel.sh

RUN chmod +x /app/run-batch-sim.sh /app/run-batch-parallel.sh \
    && sed '/<experiments>/,/<\/experiments>/d' /app/final_model_v2.nlogox > /app/final_model_v2_headless.nlogox \
    && javac -cp "/opt/NetLogo 7.0.3/lib/app/netlogo-7.0.3.jar" /app/BatchRunner.java \
    && mkdir -p /app/output

ENTRYPOINT ["/app/run-batch-parallel.sh"]
