#!/bin/sh

cd "$(dirname "$0")" || exit 1

if ! which protoc >/dev/null; then
  echo "error: protoc not installed" >&2
  exit 1
fi

protoc -I ../api/proto/zkAudit --go_out=../pkg/zkAudit --go-grpc_out=../pkg/zkAudit ../api/proto/zkAudit/zkAudit.proto