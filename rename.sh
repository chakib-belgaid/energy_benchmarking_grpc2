#!/bin/bash

l=('dotnet_grpc'
    'java_grpc_zgc'
    'java_grpc_pgc'
    'java_grpc_she'
    'java_grpc_g1gc'
    'java_micronaut'
    'java_grpc_sgc'
    'go_grpc'
    'kotlin_grpc'
    'rust_thruster_mt'
    'csharp_grpc'
    'rust_tonic_st'
    'rust_thruster_st'
    'java_aot'
    'cpp_grpc_st'
    'php_grpc'
    'elixir_grpc'
    'scala_akka'
    'swift_grpc'
    'node_grpc_st'
    'dart_grpc'
    'node_grpcjs_st'
    'ruby_grpc'
    'python_grpc'
    'crystal_grpc')

s=0
for i in ${l[@]}; do
    # echo $i
    s=$((s + 1))
    oldname=$i"_bench"
    newname="$s"_"$i"_bench
    sed -i "s/$oldname/$newname/g" $newname/Dockerfile
    # mv $i"_bench" "$s"_"$i"_bench

done
