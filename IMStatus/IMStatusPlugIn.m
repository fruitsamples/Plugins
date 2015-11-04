#import <InstantMessage/IMService.h>

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "IMStatusPlugIn.h"

#define	kQCPlugIn_Name				@"Instant Messaging Status"
#define	kQCPlugIn_Description		@"This patches returns information about the logged in user and his or her buddies on a given instant messaging service."

static NSString*					_statusStrings[] = {@"Unknown", @"Offline", @"Idle", @"Away", @"Available", @"No Status"};

@interface IMStatusPlugIn (Internal)
- (void) _updateService;
@end

@implementation IMStatusPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic outputUser, outputBuddies;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"outputUser"])
	return [NSDictionary dictionaryWithObject:@"User Status" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputBuddies"])
	return [NSDictionary dictionaryWithObject:@"Buddies Status" forKey:QCPortAttributeNameKey];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a provider (it provides data from an external source) */
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) but we need idling */
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
	if(self = [super init]) {
		/* Set a default value for our internal setting */
		_serviceName = @"AIM";
		
		pthread_mutex_init(&_statusMutex, NULL);
	}
	
	return self;
}

- (void) dealloc
{
	[_serviceName release];
	
	pthread_mutex_destroy(&_statusMutex);
	
	[super dealloc];
}

+ (NSArray*) plugInKeys
{
	/* Return the list of KVC keys corresponding to our internal settings */
	return [NSArray arrayWithObject:@"serviceName"];
}

- (void) setServiceName:(NSString*)name
{
	[_serviceName release];
	_serviceName = [name copy];
	
	[self _updateService];
}

- (NSString*) serviceName
{
	return _serviceName;
}

- (QCPlugInViewController*) createViewController
{
	/* Create a QCPlugInViewController to handle the user-interface to edit the our internal settings */
	return [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"IMStatusSettings"];
}

/* Used by NSArrayController in nib file */
- (NSArray*) allServiceNames
{
	NSMutableArray*			array = [NSMutableArray array];
	NSArray*				services = [IMService allServices];
	NSUInteger				i;
	
	for(i = 0; i < [services count]; ++i)
	[array addObject:[(IMService*)[services objectAtIndex:i] name]];
	
	return array;
}

@end

@implementation IMStatusPlugIn (Execution)

- (void) _userUpdated:(NSNotification*)notification
{
	IMPersonStatus			status = [IMService myStatus];
	
	/* Update the user status */
	pthread_mutex_lock(&_statusMutex);
	[_userStatus setObject:[NSNumber numberWithUnsignedInteger:status] forKey:@"value"];
	[_userStatus setObject:_statusStrings[status] forKey:@"title"];
	[_userStatus setObject:[NSImage imageNamed:[IMService imageNameForStatus:status]] forKey:@"image"];
	_userStatusUpdated = YES;
	pthread_mutex_unlock(&_statusMutex);
}

- (void) _buddiesUpdated:(NSNotification*)notification
{
	NSString*				screenName = [[notification userInfo] objectForKey:IMPersonScreenNameKey];
	NSDictionary*			info = [_service infoForScreenName:screenName];
	IMPersonStatus			status = [[info objectForKey:IMPersonStatusKey] unsignedIntegerValue];
	NSMutableDictionary*	dictionary;
	
	/* Build the buddy status */
	if(status != IMPersonStatusUnknown) {
		dictionary = [NSMutableDictionary dictionary];
		[dictionary setValue:screenName forKey:@"screenName"];
		[dictionary setObject:[NSNumber numberWithUnsignedInteger:status] forKey:@"statusValue"];
		[dictionary setObject:_statusStrings[status] forKey:@"statusTitle"];
		[dictionary setObject:[NSImage imageNamed:[IMService imageNameForStatus:status]] forKey:@"statusImage"];
		[dictionary setValue:[info objectForKey:IMPersonStatusMessageKey] forKey:@"statusMessage"];
		[dictionary setValue:[info objectForKey:IMPersonFirstNameKey] forKey:@"firstName"];
		[dictionary setValue:[info objectForKey:IMPersonLastNameKey] forKey:@"lastName"];
		[dictionary setValue:[info objectForKey:IMPersonPictureDataKey] forKey:@"pictureData"];
	}
	else
	dictionary = nil;
	
	/* Update the buddy status */
	pthread_mutex_lock(&_statusMutex);
	[_buddiesStatus setValue:dictionary forKey:screenName];
	_buddiesStatusUpdated = YES;
	pthread_mutex_unlock(&_statusMutex);
}

- (void) _updateService
{
	/* Terminate current connection to IM service */
	if(_service) {
		[[IMService notificationCenter] removeObserver:self name:IMMyStatusChangedNotification object:nil];
		[[IMService notificationCenter] removeObserver:self name:IMStatusImagesChangedAppearanceNotification object:nil];
		[[IMService notificationCenter] removeObserver:self name:IMPersonStatusChangedNotification object:_service];
		[[IMService notificationCenter] removeObserver:self name:IMPersonInfoChangedNotification object:_service];
		[_service release];
	}
	
	/* Open new connection to IM service */
	if(_executing) {
		_service = (_serviceName ? [[IMService serviceWithName:_serviceName] retain] : nil);
		[[IMService notificationCenter] addObserver:self selector:@selector(_userUpdated:) name:IMMyStatusChangedNotification object:nil];
		[[IMService notificationCenter] addObserver:self selector:@selector(_userUpdated:) name:IMStatusImagesChangedAppearanceNotification object:nil];
		[[IMService notificationCenter] addObserver:self selector:@selector(_buddiesUpdated:) name:IMPersonStatusChangedNotification object:_service];
		[[IMService notificationCenter] addObserver:self selector:@selector(_buddiesUpdated:) name:IMPersonInfoChangedNotification object:_service];
		
		[_userStatus removeAllObjects];
		_userStatusUpdated = NO;
		[_buddiesStatus removeAllObjects];
		_buddiesStatusUpdated = YES;
	}
	else
	_service = nil;
}

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/* Setup */
	_userStatus = [NSMutableDictionary new];
	_buddiesStatus = [NSMutableDictionary new];
	_executing = YES;
	[self _updateService];
	
	return YES;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/* Update outputs with latest user & buddy status if necessary */
	pthread_mutex_lock(&_statusMutex);
	if(_userStatusUpdated) {
		self.outputUser = [NSDictionary dictionaryWithDictionary:_userStatus];
		_userStatusUpdated = NO;
	}
	if(_buddiesStatusUpdated) {
		self.outputBuddies = [NSDictionary dictionaryWithDictionary:_buddiesStatus];
		_buddiesStatusUpdated = NO;
	}
	pthread_mutex_unlock(&_statusMutex);
	
	return YES;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* Clean up*/
	_executing = NO;
	[self _updateService];
	[_userStatus release];
	[_buddiesStatus release];
}

@end
