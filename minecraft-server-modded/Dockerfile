ARG REGISTRY=mirror.gcr.io

FROM "${REGISTRY}/amazoncorretto:25-alpine" AS builder

ARG FERIUM_VERSION
ARG MINECRAFT_VERSION
ARG FORGE_VERSION

RUN mkdir -p /builder
WORKDIR /builder

# Dowload dependencies
RUN apk add --no-cache unzip jq

ADD "https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar" server.jar
ADD "https://maven.neoforged.net/releases/net/neoforged/neoforge/${FORGE_VERSION}/neoforge-${FORGE_VERSION}-installer.jar" neoforge-installer.jar
ADD "https://github.com/gorilla-devs/ferium/releases/download/${FERIUM_VERSION}/ferium-linux-nogui.zip" ferium-linux-nogui.zip

# Set up Forge
RUN java -jar 'neoforge-installer.jar' --installServer && rm -rf 'neoforge-installer.jar'

# Install mods with Ferium
RUN unzip ferium-linux-nogui.zip && rm ferium-linux-nogui.zip
RUN chmod +x ferium
RUN ./ferium profile create                     \
		--mod-loader neo-forge                  \
		--game-version "${MINECRAFT_VERSION}"   \
		--name forge                            \
		--output-dir "/builder/mods"

COPY mods.json /builder/mods.json
RUN ./ferium add -f $(jq -r ".[].project_id" "mods.json")
RUN ./ferium upgrade


FROM "${REGISTRY}/amazoncorretto:25-alpine"

RUN mkdir -p /server
WORKDIR /server

COPY --from=builder /builder/server.jar server.jar
COPY --from=builder /builder/mods mods
COPY --from=builder /builder/libraries libraries
COPY --chmod=0700 --from=builder /builder/run.sh run.sh

ADD server.properties /server/server.properties
RUN echo "eula=true" > eula.txt
RUN echo "-Xmx12G -Xms12G" > user_jvm_args.txt

RUN adduser minecraft --no-create-home --disabled-password --gecos "" --uid 5001
RUN chown -R minecraft:minecraft /server
USER minecraft

ENTRYPOINT ["/server/run.sh", "--nogui"]
