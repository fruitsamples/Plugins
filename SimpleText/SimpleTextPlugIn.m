/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "SimpleTextPlugIn.h"

#define	kQCPlugIn_Name				@"Simple Text"
#define	kQCPlugIn_Description		@"A patch that outputs a simple text!"

@implementation SimpleTextPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic outputString;

/* The "text" property must be synthesized */
@synthesize text;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"outputString"])
	return [NSDictionary dictionaryWithObject:@"Text" forKey:QCPortAttributeNameKey];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a processor (it outputs a text string) */
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) */
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	if(self = [super init]) {
		/* Set a default value for our internal setting */
		self.text = @"Bonjour";
	}
	
	return self;
}

- (void) dealloc
{
	/* IMPORTANT: We need to set the property for our internal setting to nil on -dealloc or the property value will leak */
	self.text = nil;
	
	[super dealloc];
}

+ (NSArray*) plugInKeys
{
	/* Return the list of KVC keys corresponding to our internal settings */
	return [NSArray arrayWithObject:@"text"];
}

- (QCPlugInViewController*) createViewController
{
	/* Create a QCPlugInViewController to handle the user-interface to edit the our internal settings */
	return [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"SimpleTextSettings"];
}

@end

@implementation SimpleTextPlugIn (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/* This method is called by Quartz Composer whenever the plug-in needs to recompute its result (or if one of the keys listed in +plugInKeys has changed): simply set the output string to our internal setting */
	self.outputString = self.text;
	
	return YES;
}

@end
