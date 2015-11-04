#import <Quartz/Quartz.h>

@interface BatteryInfoPlugIn : QCPlugIn
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

/* Declare a property output port of type "Boolean" and with the key "outputInstalled" */
@property BOOL outputInstalled;

/* Declare a property output port of type "Boolean" and with the key "outputConnected" */
@property BOOL outputConnected;

/* Declare a property output port of type "Boolean" and with the key "outputCharging" */
@property BOOL outputCharging;

/* Declare a property output port of type "Number" and with the key "outputCurrent" */
@property double outputCurrent;

/* Declare a property output port of type "Number" and with the key "outputVoltage" */
@property double outputVoltage;

/* Declare a property output port of type "Number" and with the key "outputCapacity" */
@property double outputCapacity;

/* Declare a property output port of type "Number" and with the key "outputMaxCapacity" */
@property double outputMaxCapacity;

@end
