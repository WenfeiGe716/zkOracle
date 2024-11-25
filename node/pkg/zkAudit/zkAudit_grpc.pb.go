// Code generated by protoc-gen-go-grpc. DO NOT EDIT.
// versions:
// - protoc-gen-go-grpc v1.5.1
// - protoc             v5.28.3
// source: zkAudit.proto

package zkAudit

import (
	context "context"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
// Requires gRPC-Go v1.64.0 or later.
const _ = grpc.SupportPackageIsVersion9

const (
	AuditNode_SendVote_FullMethodName = "/zkAudit.AuditNode/SendVote"
)

// AuditNodeClient is the client API for AuditNode service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type AuditNodeClient interface {
	SendVote(ctx context.Context, in *SendVoteRequest, opts ...grpc.CallOption) (*SendVoteResponse, error)
}

type auditNodeClient struct {
	cc grpc.ClientConnInterface
}

func NewAuditNodeClient(cc grpc.ClientConnInterface) AuditNodeClient {
	return &auditNodeClient{cc}
}

func (c *auditNodeClient) SendVote(ctx context.Context, in *SendVoteRequest, opts ...grpc.CallOption) (*SendVoteResponse, error) {
	cOpts := append([]grpc.CallOption{grpc.StaticMethod()}, opts...)
	out := new(SendVoteResponse)
	err := c.cc.Invoke(ctx, AuditNode_SendVote_FullMethodName, in, out, cOpts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// AuditNodeServer is the server API for AuditNode service.
// All implementations must embed UnimplementedAuditNodeServer
// for forward compatibility.
type AuditNodeServer interface {
	SendVote(context.Context, *SendVoteRequest) (*SendVoteResponse, error)
	mustEmbedUnimplementedAuditNodeServer()
}

// UnimplementedAuditNodeServer must be embedded to have
// forward compatible implementations.
//
// NOTE: this should be embedded by value instead of pointer to avoid a nil
// pointer dereference when methods are called.
type UnimplementedAuditNodeServer struct{}

func (UnimplementedAuditNodeServer) SendVote(context.Context, *SendVoteRequest) (*SendVoteResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method SendVote not implemented")
}
func (UnimplementedAuditNodeServer) mustEmbedUnimplementedAuditNodeServer() {}
func (UnimplementedAuditNodeServer) testEmbeddedByValue()                   {}

// UnsafeAuditNodeServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to AuditNodeServer will
// result in compilation errors.
type UnsafeAuditNodeServer interface {
	mustEmbedUnimplementedAuditNodeServer()
}

func RegisterAuditNodeServer(s grpc.ServiceRegistrar, srv AuditNodeServer) {
	// If the following call pancis, it indicates UnimplementedAuditNodeServer was
	// embedded by pointer and is nil.  This will cause panics if an
	// unimplemented method is ever invoked, so we test this at initialization
	// time to prevent it from happening at runtime later due to I/O.
	if t, ok := srv.(interface{ testEmbeddedByValue() }); ok {
		t.testEmbeddedByValue()
	}
	s.RegisterService(&AuditNode_ServiceDesc, srv)
}

func _AuditNode_SendVote_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(SendVoteRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(AuditNodeServer).SendVote(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: AuditNode_SendVote_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(AuditNodeServer).SendVote(ctx, req.(*SendVoteRequest))
	}
	return interceptor(ctx, in, info, handler)
}

// AuditNode_ServiceDesc is the grpc.ServiceDesc for AuditNode service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var AuditNode_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "zkAudit.AuditNode",
	HandlerType: (*AuditNodeServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "SendVote",
			Handler:    _AuditNode_SendVote_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "zkAudit.proto",
}
