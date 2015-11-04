/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "MiniSOAPPlugIn.h"
#import "SOAPClient.h"

#define	kQCPlugIn_Name				@"Mini SOAP"
#define	kQCPlugIn_Description		@"Sends a message to a SOAP server and outputs the result."

@implementation MiniSOAPPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputServerURL, inputMessage, outputResult, outputProcessing; 

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputServerURL"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Server URL", QCPortAttributeNameKey, @"http://localhost:80/", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"inputMessage"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Message Body", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"outputResult"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Result Body", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"outputProcessing"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Processing", QCPortAttributeNameKey, nil];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a provider (it provides data from an outside source to the system and doesn't need to run more than once per frame) */
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time but since it uses a worker background thread, its -execute:atTime:withArguments: method needs to be called on a regular basis to watch for results */
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
	/* Initialize the mutex we use to communicate with the background thread */
	if(self = [super init])
	pthread_mutex_init(&_processingMutex, NULL);
	
	return self;
}

- (void) dealloc
{
	/* Destroy the mutex we use to communicate with the background thread */
	pthread_mutex_destroy(&_processingMutex);
	
	[super dealloc];
}

@end

@implementation MiniSOAPPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/* Reset the processing needed flag (we don't need to reset our outputs as this is done automatically by the system) */
	_processingNeeded = NO;
	
	return YES;
}

/*
This method runs from a background thread and perform the SOAP server communication.
We cannot perform this communication within the -execute:atTime:withArguments: method as it would take too long and block Quartz Composer execution.
Running the server communication asynchronously from -execute:atTime:withArguments: would not work either as this requires a runloop to be active, which is not guaranteed in the Quartz Composer environment.
*/
- (void) _processingThread:(NSArray*)args
{
	NSAutoreleasePool*		pool = [NSAutoreleasePool new];
	SOAPClient*				client;
	NSString*				string;
	NSXMLDocument*			message;
	NSError*				error;
	NSXMLNode*				node;
	
	/* Make sure this thread priority is low */
	[NSThread setThreadPriority:0.0];
	
	/* Create SOAP message */
	string = [NSString stringWithFormat:@"<?xml version=\"1.0\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:ex=\"http://www.apple.com/namespaces/cocoa/soap/example\"><soap:Body>\n%@\n</soap:Body></soap:Envelope>", [args objectAtIndex:1]];
	message = [[[NSXMLDocument alloc] initWithXMLString:string options:NSXMLNodeOptionsNone error:&error] autorelease];
	
	/* Send message to server */
	client = [[[SOAPClient alloc] initWithServerURL:[NSURL URLWithString:[args objectAtIndex:0]]] autorelease];
	if(client && message)
	message = [client sendMessageAndWaitForReply:message timeOut:30.0];
	else
	message = nil;
	
	/* Extract response */
	node = [message rootElement];
	if([node childCount] == 1) {
		node = [node childAtIndex:0];
		if([node childCount] == 1)
		node = [node childAtIndex:0];
		else
		node = nil;
	}
	else
	node = nil;
	
	/* Pass the response back to the execution thread and signal we're done by releasing the mutex */
	_processingResult = (node ? [[node description] copy] : (id)kCFNull);
	pthread_mutex_unlock(&_processingMutex);
	
	[pool release];
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/* If a processing result is available from the background thread, put it on "outputResult" and set "outputProcessing" to NO */
	if(_processingResult) {
		self.outputResult = (_processingResult == (id)kCFNull ? nil : _processingResult);
		self.outputProcessing = NO;
		[_processingResult release];
		_processingResult = nil;
	}
	
	/* Check if our message parameters have changed, and if yes, set the processing needed flag */
	if([self didValueForInputKeyChange:@"inputServerURL"] || [self didValueForInputKeyChange:@"inputMessage"])
	_processingNeeded = YES;
	
	/* Check if we need to send a message to the server */
	if(_processingNeeded) {
		/* Attempt to acquire the mutex which will fail if there's already a background thread running */
		if(pthread_mutex_trylock(&_processingMutex) == 0) {
			/* Start background thread and clear processing needed flag */
			[NSThread detachNewThreadSelector:@selector(_processingThread:) toTarget:self withObject:[NSArray arrayWithObjects:self.inputServerURL, self.inputMessage, nil]];
			_processingNeeded = NO;
			
			/* Set "outputSearching" to YES */
			self.outputProcessing = YES;
		}
		/* We weren't able to start the processing, but since the processing needed flag has not been cleared, we will try again the next time -execute:atTime:withArguments: is called */
	}
	
	return YES;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* If there's a background thread running, block until it is done (this will do nothing if there's no background thread) */
	pthread_mutex_lock(&_processingMutex);
	pthread_mutex_unlock(&_processingMutex);
	
	/* Clear the background thread result if any */
	[_processingResult release];
	_processingResult = nil;
}
	
@end
