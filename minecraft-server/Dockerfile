ARG REGISTRY=mirror.gcr.io

FROM "${REGISTRY}/amazoncorretto:25-alpine"

RUN mkdir -p /server
WORKDIR /server


ADD https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar server.jar
ADD server.properties /server/server.properties
RUN echo "eula=true" > eula.txt

RUN adduser minecraft --no-create-home --disabled-password --gecos ""
RUN chown -R minecraft:minecraft /server
USER minecraft

ENTRYPOINT ["java", "-Xmx12G", "-Xms12G", "-jar", "server.jar", "--nogui"]
