FROM adoptopenjdk:14.0.2_8-jre-hotspot-bionic

WORKDIR /app
COPY 07_java_grpc_sgc_bench /app
COPY proto/helloworld/helloworld.proto /app/src/main/proto/helloworld.proto

RUN /app/gradlew installDist

ENV GC "-XX:+UnlockExperimentalVMOptions -XX:+UseZGC"
ENV JAVA_OPTS "${GC} -XX:MinRAMPercentage=70 -XX:MaxRAMPercentage=70"

ENTRYPOINT [ "/app/build/install/examples/bin/hello-world-server" ]
