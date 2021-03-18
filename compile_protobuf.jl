# compile the protobuf files

using ProtoBuf
ENV["JULIA_PROTOBUF_MODULE_POSTFIX"] = 1
run(ProtoBuf.protoc(`-I=proto --julia_out=src/proto proto/fileformat.proto proto/osmformat.proto`))