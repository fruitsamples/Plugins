#import <Quartz/Quartz.h>
#import <pthread.h>

@interface MiniSOAPPlugIn : QCPlugIn
{
	pthread_mutex_t				_processingMutex;
	NSString*					_processingResult;
	
	BOOL						_processingNeeded;
}

/* Declare a property input port of type "String" and with the key "inputServerURL" */
@property(assign) NSString* inputServerURL;

/* Declare a property input port of type "String" and with the key "inputMessage" */
@property(assign) NSString* inputMessage;

/* Declare a property output port of type "Structure" and with the key "outputResult" */
@property(assign) NSString* outputResult;

/* Declare a property output port of type "Boolean" and with the key "outputProcessing" */
@property BOOL outputProcessing;

@end
