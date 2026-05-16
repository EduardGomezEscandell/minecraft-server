ARG REGISTRY=mirror.gcr.io

FROM "${REGISTRY}/amazoncorretto:25-alpine" AS base-builder

ARG FERIUM_VERSION
ARG MINECRAFT_VERSION
ARG FORGE_VERSION

RUN mkdir -p /builder
WORKDIR /builder

# Dowload dependencies
RUN apk add --no-cache unzip jq

ADD "https://github.com/gorilla-devs/ferium/releases/download/${FERIUM_VERSION}/ferium-linux-nogui.zip" ferium-linux-nogui.zip

# Get Ferium ready and create the mods directory with the correct profile
RUN unzip ferium-linux-nogui.zip && rm ferium-linux-nogui.zip
RUN chmod +x ferium
RUN ./ferium profile create                     \
		--mod-loader neo-forge                  \
		--game-version "${MINECRAFT_VERSION}"   \
		--name forge                            \
		--output-dir "/builder/mods"

		
# Target for adding mods to the minecraft client
FROM base-builder AS client-builder
COPY mods.json /builder/mods.json
RUN ./ferium add -f $(jq -r '.[] | select(.client != null) | .project_id' "mods.json") && ./ferium upgrade

# Target for building the server with mods, this is used in the final image
FROM base-builder AS server-builder
ADD "https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar" server.jar
ADD "https://maven.neoforged.net/releases/net/neoforged/neoforge/${FORGE_VERSION}/neoforge-${FORGE_VERSION}-installer.jar" neoforge-installer.jar
RUN java -jar 'neoforge-installer.jar' --installServer && rm -rf neoforge-installer.jar
COPY mods.json /builder/mods.json
RUN ./ferium add -f $(jq -r ".[] | select(.server != null) | .project_id" "mods.json") && ./ferium upgrade

# Final image with the server and mods, this is the image that will be used to run the server
FROM "${REGISTRY}/amazoncorretto:25-alpine" AS server

RUN mkdir -p /server
WORKDIR /server

COPY --from=server-builder /builder/server.jar server.jar
COPY --from=server-builder /builder/mods mods
COPY --from=server-builder /builder/libraries libraries
COPY --chmod=0700 --from=server-builder /builder/run.sh run.sh

ADD server.properties /server/server.properties
RUN echo "eula=true" > eula.txt
RUN echo "-Xmx12G -Xms12G" > user_jvm_args.txt

RUN adduser minecraft --no-create-home --disabled-password --gecos "" --uid 5001
RUN chown -R minecraft:minecraft /server
USER minecraft

ENTRYPOINT ["/server/run.sh", "--nogui"]
