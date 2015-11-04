#import <Quartz/Quartz.h>
#import <pthread.h>

@interface SpotlightSearchPlugIn : QCPlugIn
{
	pthread_mutex_t				_searchMutex;
	NSArray*					_searchResults;
	
	BOOL						_searchNeeded;
}

/* Declare a property input port of type "String" and with the key "inputQuery" */
@property(assign) NSString* inputQuery;

/* Declare a property input port of type "String" and with the key "inputType" */
@property(assign) NSString* inputType;

/* Declare a property output port of type "Structure" and with the key "outputResults" */
@property(assign) NSArray* outputResults;

/* Declare a property output port of type "Boolean" and with the key "outputSearching" */
@property BOOL outputSearching;

@end
