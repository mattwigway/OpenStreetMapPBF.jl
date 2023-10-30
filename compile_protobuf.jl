# compile the protobuf files

using ProtoBuf
ProtoBuf.protojl(["proto/osmformat.proto", "proto/fileformat.proto"], ".", "src/proto/")