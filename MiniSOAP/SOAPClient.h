/*
 File: SOAPClient.h
 
 Abstract: Interface description for a basic SOAP client class
*/ 

#import <Foundation/Foundation.h>

@interface SOAPClient : NSObject
{
@private
	NSURL*			_url;
}
- (id) initWithServerURL:(NSURL*)url;
- (NSXMLDocument*) sendMessageAndWaitForReply:(NSXMLDocument*)message timeOut:(NSTimeInterval)timeOut;
@end
