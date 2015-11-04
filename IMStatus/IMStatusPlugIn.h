#import <Quartz/Quartz.h>
#import <pthread.h>

@interface IMStatusPlugIn : QCPlugIn
{
	NSString*					_serviceName;
	
	BOOL						_executing;
	IMService*					_service;
	pthread_mutex_t				_statusMutex;
	NSMutableDictionary*		_userStatus;
	BOOL						_userStatusUpdated;
	NSMutableDictionary*		_buddiesStatus;
	BOOL						_buddiesStatusUpdated;
}

/* Declare a property output port of type "Structure" and with the key "outputUser" */
@property(assign) NSDictionary* outputUser;

/* Declare a property output port of type "Structure" and with the key "outputBuddies" */
@property(assign) NSDictionary* outputBuddies;

@end
