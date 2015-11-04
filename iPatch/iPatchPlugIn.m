/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "iPatchPlugIn.h"

#define	kQCPlugIn_Name				@"iPatch"
#define	kQCPlugIn_Description		@"Convert any name to an \"iName\""

@implementation iPatchPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputString, outputString;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputString"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Name", QCPortAttributeNameKey, @"Pod", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"outputString"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"iName", QCPortAttributeNameKey, nil];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a processor (it just processes a text string) */
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) */
	return kQCPlugInTimeModeNone;
}

@end

@implementation iPatchPlugIn (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/* This method is called by Quartz Composer whenever the plug-in needs to recompute its result: retrieve the input string and compute the output string */
	self.outputString = [@"i" stringByAppendingString:[self.inputString capitalizedString]];
	
	return YES;
}

@end
