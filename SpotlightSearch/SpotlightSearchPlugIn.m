/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "SpotlightSearchPlugIn.h"

#define	kQCPlugIn_Name				@"Spotlight Search"
#define	kQCPlugIn_Description		@"Search for files of a given type matching a Spotlight query. The file type is expressed as Uniform Type Identifier e.g. \"public.image\".\n\nRefer to the Apple documentation for a list of available types:\nhttp://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/utilist/chapter_4_section_1.html."

@implementation SpotlightSearchPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputQuery, inputType, outputResults, outputSearching;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputQuery"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Search Query", QCPortAttributeNameKey, @"Apple", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"inputType"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"File Type (UTI)", QCPortAttributeNameKey, @"public.image", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"outputResults"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Results", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"outputSearching"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Searching", QCPortAttributeNameKey, nil];
	
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
	pthread_mutex_init(&_searchMutex, NULL);
	
	return self;
}

- (void) dealloc
{
	/* Destroy the mutex we use to communicate with the background thread */
	pthread_mutex_destroy(&_searchMutex);
	
	[super dealloc];
}

@end

@implementation SpotlightSearchPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/* Reset the search needed flag (we don't need to reset our outputs as this is done automatically by the system) */
	_searchNeeded = NO;
	
	return YES;
}

/*
This method runs from a background thread and perform the Spotlight search synchronously.
We cannot perform this search within the -execute:atTime:withArguments: method as it would take too long and block Quartz Composer execution.
Running the search asynchronously from -execute:atTime:withArguments: would not work either as this requires a runloop to be active, which is not guaranteed in the Quartz Composer environment.
*/
- (void) _searchThread:(NSArray*)args
{
	NSAutoreleasePool*		pool = [NSAutoreleasePool new];
	NSMutableArray*			resultList = [NSMutableArray new];
	CFIndex					i;
	MDQueryRef				query;
	CFMutableArrayRef		sortingAttributes;
	MDItemRef				item;
	CFStringRef				attribute;
	NSString*				string;
	NSMutableDictionary*	dictionary;
	
	/* Make sure this thread priority is low */
	[NSThread setThreadPriority:0.0];
	
	/* Contruct a very simple Spotlight query string for files containing the search string and matching an optional UTI */
	if([[args objectAtIndex:0] length]) {
		if([[args objectAtIndex:1] length])
		string = [NSString stringWithFormat:@"(* = \"%@\"cdw) && (kMDItemContentTypeTree = \"%@\")", [args objectAtIndex:0], [args objectAtIndex:1]];
		else
		string = [NSString stringWithFormat:@"(* = \"%@\"cdw)", [args objectAtIndex:0]];
	}
	else
	string = nil;
	
	if(string) {
		/* Create the Spotlight query */
		sortingAttributes = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
		CFArrayAppendValue(sortingAttributes, kMDItemDisplayName);
		query = MDQueryCreate(kCFAllocatorDefault, (CFStringRef)string, NULL, sortingAttributes);
		CFRelease(sortingAttributes);
		
		if(query) {
			/* Execute the query synchronously */
			if(MDQueryExecute(query, kMDQuerySynchronous)) {
				/* Create the result list as an array of dictionaries containing "name", "path" and "type" entries for each result */
				for(i = 0; i < MDQueryGetResultCount(query); ++i) {
					item = (MDItemRef)MDQueryGetResultAtIndex(query, i);
					dictionary = [NSMutableDictionary new];
					
					attribute = MDItemCopyAttribute(item, kMDItemDisplayName);
					if(attribute) {
						[dictionary setObject:(id)attribute forKey:@"name"];
						CFRelease(attribute);
					}
					
					attribute = MDItemCopyAttribute(item, kMDItemPath);
					if(attribute) {
						[dictionary setObject:(id)attribute forKey:@"path"];
						CFRelease(attribute);
					}
					
					attribute = MDItemCopyAttribute(item, kMDItemContentType);
					if(attribute) {
						[dictionary setObject:(id)attribute forKey:@"type"];
						CFRelease(attribute);
					}
					
					if([dictionary count])
					[resultList addObject:dictionary];
					[dictionary release];
				}
			}
			CFRelease(query);
		}
	}
	
	/* Pass the result array back to the execution thread and signal we're done by releasing the mutex */
	_searchResults = resultList;
	pthread_mutex_unlock(&_searchMutex);
	
	[pool release];
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/* If search results are available from the background thread, put them on "outputResults" and set "outputSearching" to NO */
	if(_searchResults) {
		self.outputResults = _searchResults;
		self.outputSearching = NO;
		[_searchResults release];
		_searchResults = nil;
	}
	
	/* Check if our search parameters have changed, and if yes, set the search needed flag */
	if([self didValueForInputKeyChange:@"inputQuery"] || [self didValueForInputKeyChange:@"inputType"])
	_searchNeeded = YES;
	
	/* Check if we need to perform a search */
	if(_searchNeeded) {
		/* Attempt to acquire the mutex which will fail if there's already a background thread running */
		if(pthread_mutex_trylock(&_searchMutex) == 0) {
			/* Start background thread and clear search needed flag */
			[NSThread detachNewThreadSelector:@selector(_searchThread:) toTarget:self withObject:[NSArray arrayWithObjects:self.inputQuery, self.inputType, nil]];
			_searchNeeded = NO;
			
			/* Set "outputSearching" to YES */
			self.outputSearching = YES;
		}
		/* We weren't able to start the search, but since the search needed flag has not been cleared, we will try again the next time -execute:atTime:withArguments: is called */
	}
	
	return YES;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* If there's a background thread running, block until it is done (this will do nothing if there's no background thread) */
	pthread_mutex_lock(&_searchMutex);
	pthread_mutex_unlock(&_searchMutex);
	
	/* Clear the background thread results if any */
	[_searchResults release];
	_searchResults = nil;
}
	
@end
