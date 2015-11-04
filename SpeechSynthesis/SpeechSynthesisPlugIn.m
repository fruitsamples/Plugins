/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "SpeechSynthesisPlugIn.h"

#define	kQCPlugIn_Name				@"Speech Synthesis"
#define	kQCPlugIn_Description		@"Use Mac OS X built-in speech synthetizer to speak a string of text."

@implementation SpeechSynthesisPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputVoice, inputText;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputVoice"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Voice Name", QCPortAttributeNameKey, @"Kathy", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"inputText"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Text", QCPortAttributeNameKey, @"Hello World!", QCPortAttributeDefaultValueKey, nil];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a consumer (it renders to the speech synthetizer) */
	return kQCPlugInExecutionModeConsumer;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) */
	return kQCPlugInTimeModeNone;
}

@end

@implementation SpeechSynthesisPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/* Create synthetizer */
	_synthetizer = [[NSSpeechSynthesizer alloc] initWithVoice:[NSSpeechSynthesizer defaultVoice]];
	
	return (_synthetizer ? YES : NO);
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	BOOL						speakText = [self didValueForInputKeyChange:@"inputText"];
	
	/* Update synthetizer voice if necessary */
	if([self didValueForInputKeyChange:@"inputVoice"] && [self.inputVoice length]) {
		[_synthetizer stopSpeaking];
		[_synthetizer setVoice:[@"com.apple.speech.synthesis.voice." stringByAppendingString:self.inputVoice]];
		speakText = YES;
	}
	
	/* Speak text if necessary */
	if(speakText) {
		[_synthetizer stopSpeaking];
		if([self.inputText length])
		[_synthetizer startSpeakingString:self.inputText];
	}
	
	return YES;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* Destroy synthetizer */
	[_synthetizer stopSpeaking];
	[_synthetizer release];
	_synthetizer = nil;
}

@end
