/*
 File: server_main.m
 
 Abstract: Main program for SOAP server.
*/ 

#import <Cocoa/Cocoa.h>
#import "HTTPServer.h"


@interface SOAPServer : NSObject {
    HTTPServer *httpServ;
}
@end


int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    SOAPServer *server = [[SOAPServer alloc] initWithName:@"SOAP adder"];
    [[NSRunLoop currentRunLoop] run]; // this will not return
    [server release];
    [pool release];
    exit(0);
}


@implementation SOAPServer

- (id)initWithName:(NSString *)name {
    httpServ = [[HTTPServer alloc] init];
    [httpServ setPort:54000];
	[httpServ setType:@"_http._tcp."];
    [httpServ setName:name];
    [httpServ setDelegate:self];
    NSError *error = nil;
    if (![httpServ start:&error]) {
        NSLog(@"Error starting server: %@", error);
    } else {
        NSLog(@"Starting server on port %d", [httpServ port]);
    }
    return self;
}

- (void)dealloc {
    [httpServ release];
    [super dealloc];
}

- (NSNumber *)add:(NSNumber *)num1 to:(NSNumber *)num2 {
    return [NSNumber numberWithDouble:[num1 doubleValue] + [num2 doubleValue]];
}

- (void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess {
    CFHTTPMessageRef request = [mess request];

    NSString *vers = [(id)CFHTTPMessageCopyVersion(request) autorelease];
    if (!vers || ![vers isEqual:(id)kCFHTTPVersion1_1]) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 505, NULL, vers ? (CFStringRef)vers : kCFHTTPVersion1_0); // Version Not Supported
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

    NSString *method = [(id)CFHTTPMessageCopyRequestMethod(request) autorelease];
    if (!method) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1); // Bad Request
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

#if 0
    // useful for testing with Safari
    if ([method isEqual:@"GET"]) {
        [[conn server] setDocumentRoot:[NSURL fileURLWithPath:@"/"]];
        [conn performDefaultRequestHandling:mess];
        return;
    }
#endif

    if ([method isEqual:@"POST"]) {
        NSError *error = nil;
        NSData *data = [(id)CFHTTPMessageCopyBody(request) autorelease];
        NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithData:data options:NSXMLNodeOptionsNone error:&error] autorelease];
        NSArray *array = [doc nodesForXPath:@"soap:Envelope/soap:Body/ex:MethodName" error:&error];
        NSString *selName = [[array objectAtIndex:0] objectValue];

        // Recognize each method that is supported (only one), unpack the arguments,
        // perform the service, package up the result, and set the response.
        if ([selName isEqual:@"add:to:"]) {
            NSArray *array = [doc nodesForXPath:@"soap:Envelope/soap:Body/ex:Parameters/ex:Parameter" error:&error];
            if (2 != [array count]) {
                CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1); // Bad Request
                [mess setResponse:response];
                CFRelease(response);
                return;
            }
            
            NSXMLNode *node1 = [array objectAtIndex:0];
            NSNumber *num1 = [NSNumber numberWithDouble:[[node1 objectValue] doubleValue]];
            NSXMLNode *node2 = [array objectAtIndex:1];
            NSNumber *num2 = [NSNumber numberWithDouble:[[node2 objectValue] doubleValue]];
            NSNumber *ret = [self add:num1 to:num2];
            NSString *xml = [NSString stringWithFormat:@"<?xml version=\"1.0\"?> <soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:ex=\"http://www.apple.com/namespaces/cocoa/soap/example\"> <soap:Body> <ex:Result>%@</ex:Result> </soap:Body> </soap:Envelope>", ret];
            NSError *error = nil;
            NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:xml options:NSXMLNodeOptionsNone error:&error] autorelease];
            NSData *data = [doc XMLData];
            CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1); // OK
            CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%d", [data length]]);
            CFHTTPMessageSetBody(response, (CFDataRef)data);
            [mess setResponse:response];
            CFRelease(response);
            return;
        }
        
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1); // Bad Request
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 405, NULL, kCFHTTPVersion1_1); // Method Not Allowed
    [mess setResponse:response];
    CFRelease(response);
}

@end

