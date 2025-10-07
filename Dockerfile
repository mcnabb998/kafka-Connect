# syntax=docker/dockerfile:1.4

FROM alpine:3.19 AS prep
WORKDIR /workspace
COPY scripts/ scripts/
COPY probes/ probes/
RUN chmod +x scripts/* probes/*

FROM eclipse-temurin:17-jre-jammy AS runtime
ARG APP_HOME=/opt/kafka-connect
ARG APP_USER=appuser
ARG APP_GROUP=appuser
ARG APP_UID=1001
ARG APP_GID=1001

ENV KAFKA_HEAP_OPTS="" \
    JAVA_OPTS_APPEND=""

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl jq netcat-openbsd procps \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid ${APP_GID} ${APP_GROUP} \
    && useradd --system --home ${APP_HOME} --uid ${APP_UID} --gid ${APP_GID} \
        --shell /bin/bash ${APP_USER}

RUN mkdir -p ${APP_HOME}/bin ${APP_HOME}/lib ${APP_HOME}/config ${APP_HOME}/plugins ${APP_HOME}/probes

COPY docker/artifacts/ ${APP_HOME}/lib/
COPY --from=prep /workspace/scripts/ ${APP_HOME}/bin/
COPY --from=prep /workspace/probes/ ${APP_HOME}/probes/

RUN chown -R ${APP_USER}:${APP_GROUP} ${APP_HOME} \
    && chmod +x ${APP_HOME}/bin/start_script ${APP_HOME}/bin/run-env.sh \
    && chmod +x ${APP_HOME}/probes/*

USER ${APP_USER}
WORKDIR ${APP_HOME}

ENTRYPOINT ["/opt/kafka-connect/bin/start_script"]
