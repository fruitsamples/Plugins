#import "ImageInfo.h"

#define	kQCPlugIn_Name				@"Image Information"
#define	kQCPlugIn_Description		@"Show image in setting pane"

@interface ImageInfo (Internal)

- (void) _releasedUnusedControllers;
- (void) _setImageForControllers:(id<QCPlugInInputImageSource>) image;

@end

@implementation ImageInfo

@dynamic inputImage;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputImage"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a consumer */
	return kQCPlugInExecutionModeConsumer;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method). Only needs to be executed when input image changes */
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	/* When plug-in is initialized. Initialized our array that will keep track or active plug-in controllers */
	if (self = [super init])
		_plugInControllers = [NSMutableArray new];
		
	return self;
}

- (void) dealloc
{
	/* Release plug-in controller array at dealloc */
	[_plugInControllers release];
	[super dealloc];
}

- (QCPlugInViewController*) createViewController
{
	QCPlugInViewController*			controller;

	/* Create plug-in controller and keep it around */
	controller = [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"ImageInfoUI"];

	/* In the case of when the setting pane is showed but image does not change, execute won't be called 
	   We then need to set the image manually on the QCView */
	[(QCView*)[[[controller view] subviews] objectAtIndex:0] setValue:_image forInputKey:@"Image"];
	
	[_plugInControllers addObject:controller];
	
	return controller;
}

@end

@implementation ImageInfo (Internal)

/* Release unused plug-in controllers */
- (void) _releasedUnusedControllers
{
	NSInteger		i;
	
	for (i=[_plugInControllers count]-1; i>=0; --i) {
		if ([[_plugInControllers objectAtIndex:i] retainCount] == 1)
			[_plugInControllers removeObjectAtIndex:i];
	}
}

/* Sets all plug-in controller to the given image */
- (void) _setImageForControllers:(id<QCPlugInInputImageSource>) image
{
	NSUInteger		i;

	for (i=0; i<[_plugInControllers count]; ++i)
		[(QCView*)[[[[_plugInControllers objectAtIndex:i] view] subviews] objectAtIndex:0] setValue:self.inputImage forInputKey:@"Image"];
}

@end

@implementation ImageInfo (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/* Release unused plug-in controllers */
	if ([_plugInControllers count])
		[self _releasedUnusedControllers];
	
	/* Sets current input image on all controllers */
	if ([_plugInControllers count])
		[self _setImageForControllers:self.inputImage];
	
	/* Keep a reference to the image in the case a setting pane is showed later */
	if (_image != self.inputImage) {
		[(id)_image release];
		_image = [(id)self.inputImage retain];
	}
	/* Otherwise, this plug-in does nothing */
	
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context;
{
	/* Release unused plug-in controllers */
	[self _releasedUnusedControllers];
}

- (void) stopExecution:(id<QCPlugInContext>)context;
{
	/* Release unused plug-in controllers */
	[self _releasedUnusedControllers];
}

@end