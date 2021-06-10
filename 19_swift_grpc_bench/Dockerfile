FROM swift:5.3-focal

WORKDIR /app

# Resolve package dependencies early and store them in the build cache,
# for faster subsequent builds.
COPY 19_swift_grpc_bench/Package.swift /app
RUN swift package resolve

COPY 19_swift_grpc_bench /app
RUN swift build -c release -Xswiftc -enforce-exclusivity=unchecked

ENTRYPOINT [ "/app/.build/release/Server" ]
