/*
 File: SOAPClient.m
 
 Abstract: Implementation for a basic SOAP client class
*/ 

#import "SOAPClient.h"

@interface SOAPConnection : NSURLConnection
{
@private
	NSMutableData*		_data;
	BOOL				_finished;
}
- (void) appendData:(NSData*)data;
- (NSData*) data;
- (void) setFinished:(BOOL)finished;
- (BOOL) isFinished;
@end

@implementation SOAPConnection

- (void) dealloc
{
	[_data release];

	[super dealloc];
}

- (NSData*)data
{
	return _data;
}

- (void) appendData:(NSData*)data
{
	if(_data == nil)
	_data = [NSMutableData new];
	
	[_data appendData:data];
}

- (void) setFinished:(BOOL)finished
{
	_finished = finished;
}

- (BOOL) isFinished
{
	return _finished;
}

@end

@implementation SOAPClient

- (id) initWithServerURL:(NSURL*)url
{
	if(url == nil) {
		[self release];
		return nil;
	}
	
	if(self = [super init])
	_url = [url copy];
	
	return self;
}

- (void) dealloc
{
	[_url release];
	
	[super dealloc];
}

- (NSXMLDocument*) sendMessageAndWaitForReply:(NSXMLDocument*)message timeOut:(NSTimeInterval)timeOut
{
	NSData*					data = [message XMLData];
	NSMutableURLRequest*	request;
	SOAPConnection*			connection;
	NSError*				error;
	NSTimeInterval			startTime;
	
	if(data == nil)
	return nil;
	
	request = [[NSMutableURLRequest alloc] initWithURL:_url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:timeOut];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:data];
	[request setValue:[NSString stringWithFormat:@"%d", [data length]] forHTTPHeaderField:@"Content-Length"];
	connection = [[SOAPConnection alloc] initWithRequest:request delegate:self];
	[request release];
	
	if(connection) {
		startTime = [NSDate timeIntervalSinceReferenceDate];
		while(![connection isFinished]) {
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
			
			if([NSDate timeIntervalSinceReferenceDate] >= startTime + timeOut) {
				[connection cancel];
				[connection release];
				connection = nil;
				break;
			}
		}
	}
	
	message = ([connection data] ? [[NSXMLDocument alloc] initWithData:[connection data] options:NSXMLNodeOptionsNone error:&error] : nil);
	
	[connection release];
	
	return [message autorelease];
}

- (void) connection:(SOAPConnection*)connection didReceiveData:(NSData*)data
{
	[connection appendData:data];
}

- (void) connectionDidFinishLoading:(SOAPConnection*)connection
{
	[connection setFinished:YES];
}

- (void) connection:(SOAPConnection*)connection didFailWithError:(NSError*)error
{
	[connection setFinished:YES];
}

@end
