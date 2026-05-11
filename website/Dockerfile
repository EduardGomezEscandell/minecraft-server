ARG REGISTRY=mirror.gcr.io

FROM "${REGISTRY}/ubuntu:22.04" AS build

RUN apt update && apt install -y --no-install-recommends jq sed

ARG SERVER_IP
ARG SERVER_PORT1
ARG SERVER_PORT2

ADD . /build
WORKDIR /build

RUN ./replace_placeholders.sh "./src" "${SERVER_IP}" "${SERVER_PORT1}" "${SERVER_PORT2}"
RUN rm replace_placeholders.sh mods.json

FROM "${REGISTRY}/python:3.10-slim"

COPY --from=0 /build/src /app

RUN adduser webserver --no-create-home --disabled-password --gecos "" --uid 5002
RUN chown -R webserver:webserver /app

USER webserver
EXPOSE 3000

ENTRYPOINT ["python3", "-m", "http.server", "3000", "--directory", "/app", "--bind", "0.0.0.0"]