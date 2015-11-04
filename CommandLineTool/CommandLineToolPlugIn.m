/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "CommandLineToolPlugIn.h"

#define	kQCPlugIn_Name				@"Command Line Tool"
#define	kQCPlugIn_Description		@"Runs a command line tool synchronously."

@implementation CommandLineToolPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputPath, inputStandardIn, outputStatus, outputStandardOut, outputStandardError;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputPath"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Path", QCPortAttributeNameKey, @"/bin/ls", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"inputStandardIn"])
	return [NSDictionary dictionaryWithObject:@"Standard In" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputStatus"])
	return [NSDictionary dictionaryWithObject:@"Output Status" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputStandardOut"])
	return [NSDictionary dictionaryWithObject:@"Standard Out" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputStandardError"])
	return [NSDictionary dictionaryWithObject:@"Standard Error" forKey:QCPortAttributeNameKey];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a processor (it runs a command line tool) */
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) */
	return kQCPlugInTimeModeNone;
}

+ (NSArray*) plugInKeys
{
	/* Return the list of KVC keys corresponding to our internal settings */
	return [NSArray arrayWithObject:@"argumentCount"];
}

- (BOOL) validateArgumentCount:(id*)ioValue error:(NSError**)outError
{
	/* Make sure the "argumentCount" new value is valid */
	if([(NSNumber*)*ioValue integerValue] < 0)
	*ioValue = [NSNumber numberWithUnsignedInteger:0];
	
	return YES;
}

- (void) setArgumentCount:(NSUInteger)newCount
{
	NSUInteger				i;
	
	/* Update argument input ports */
	if(newCount > _argumentCount) {
		for(i = _argumentCount; i < newCount; ++i)
		[self addInputPortWithType:QCPortTypeString forKey:[NSString stringWithFormat:@"argument_%i", i] withAttributes:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Argument #%i", i + 1] forKey:QCPortAttributeNameKey]];
	}
	else if(newCount < _argumentCount) {
		for(i = newCount; i < _argumentCount; ++i)
		[self removeInputPortForKey:[NSString stringWithFormat:@"argument_%i", i]];
	}
	
	/* Save new argument count */
	_argumentCount = newCount;
}

- (NSUInteger) argumentCount
{
	return _argumentCount;
}

- (QCPlugInViewController*) createViewController
{
	/* Create a QCPlugInViewController to handle the user-interface to edit the our internal settings */
	return [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"CommandLineToolSettings"];
}

@end

@implementation NSMutableData (CommandLineToolPlugIn)

/* Extend the NSMutableData class to add a method called by NSFileHandleDataAvailableNotification to automatically append the new data */
- (void) _CommandLineToolPlugInFileHandleDataAvailable:(NSNotification*)notification
{
	NSFileHandle*			fileHandle = [notification object];
	
	[self appendData:[fileHandle availableData]];
	
	[fileHandle waitForDataInBackgroundAndNotify];
}

@end

@implementation CommandLineToolPlugIn (Execution)

- (int) _runTask:(NSTask*)task inData:(NSData*)inData outData:(NSData**)outData errorData:(NSData**)errorData
{
	NSPipe*				inPipe = nil;
	NSPipe*				outPipe = nil;
	NSPipe*				errorPipe = nil;
	NSFileHandle*		fileHandle;
	
	/* Reset output variables */
	if(outData)
	*outData = nil;
	if(errorData)
	*errorData = nil;
	
	/* Safe check */
	if(task == nil)
	return -1;
	
	/* Create standard input pipe */
	if([inData length]) {
		if(inPipe = [NSPipe new]) {
			[task setStandardInput:inPipe];
			[inPipe release];
		}
		else {
			task = nil;
			goto Exit;
		}
	}
	
	/* Create standard output pipe */
	if(outData) {
		if(outPipe = [NSPipe new]) {
			[task setStandardOutput:outPipe];
			[outPipe release];
		}
		else {
			task = nil;
			goto Exit;
		}
	}
	
	/* Create standard error pipe */
	if(errorData) {
		if(errorPipe = [NSPipe new]) {
			[task setStandardError:errorPipe];
			[errorPipe release];
		}
		else {
			task = nil;
			goto Exit;
		}
	}
	
	/* Launch task */
NS_DURING
	[task launch];
NS_HANDLER
	task = nil;
NS_ENDHANDLER
	if(task == nil)
	goto Exit;
	
	/* Write data to standard input pipe */
	if(fileHandle = [inPipe fileHandleForWriting]) {
NS_DURING
		[fileHandle writeData:inData];
		[fileHandle closeFile];
NS_HANDLER
		[task terminate];
		[task interrupt];
		task = nil;
NS_ENDHANDLER
	}
	if(task == nil)
	goto Exit;
	
	/* Wait for task to complete and read data from standard output and standard error pipes in background */
	if(fileHandle = [outPipe fileHandleForReading]) {
		*outData = [NSMutableData data];
		[[NSNotificationCenter defaultCenter] addObserver:*outData selector:@selector(_CommandLineToolPlugInFileHandleDataAvailable:) name:NSFileHandleDataAvailableNotification object:fileHandle];
		[fileHandle waitForDataInBackgroundAndNotify];
	}
	if(fileHandle = [errorPipe fileHandleForReading]) {
		*errorData = [NSMutableData data];
		[[NSNotificationCenter defaultCenter] addObserver:*errorData selector:@selector(_CommandLineToolPlugInFileHandleDataAvailable:) name:NSFileHandleDataAvailableNotification object:fileHandle];
		[fileHandle waitForDataInBackgroundAndNotify];
	}
	[task waitUntilExit];
	if(fileHandle = [errorPipe fileHandleForReading]) {
		[[NSNotificationCenter defaultCenter] removeObserver:*errorData name:NSFileHandleDataAvailableNotification object:fileHandle];
		[(NSMutableData*)*errorData appendData:[fileHandle readDataToEndOfFile]];
	}
	if(fileHandle = [outPipe fileHandleForReading]) {
		[[NSNotificationCenter defaultCenter] removeObserver:*outData name:NSFileHandleDataAvailableNotification object:fileHandle];
		[(NSMutableData*)*outData appendData:[fileHandle readDataToEndOfFile]];
	}
	
Exit:
	[[inPipe fileHandleForReading] closeFile];
	[[inPipe fileHandleForWriting] closeFile];
	[[outPipe fileHandleForReading] closeFile];
	[[outPipe fileHandleForWriting] closeFile];
	[[errorPipe fileHandleForReading] closeFile];
	[[errorPipe fileHandleForWriting] closeFile];
	
	return (task ? [task terminationStatus] : -1);
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	NSTask*					task;
	NSMutableArray*			args;
	NSUInteger				i;
	NSData*					outData;
	NSData*					errorData;
	int						status;
	
	/* Make sure we have a path */
	if(![self.inputPath length]) {
		self.outputStatus = 0;
		self.outputStandardOut = @"";
		self.outputStandardError = @"";
		return YES;
	}
	
	/* Create task */
	task = [NSTask new];
	[task setLaunchPath:[self.inputPath stringByStandardizingPath]];
	if(_argumentCount) {
		args = [NSMutableArray new];
		for(i = 0; i < _argumentCount; ++i)
		[args addObject:[self valueForInputKey:[NSString stringWithFormat:@"argument_%i", i]]];
		[task setArguments:args];
		[args release];
	}
	
	/* Execute task */
	self.outputStatus = [self _runTask:task inData:([self.inputStandardIn length] ? [self.inputStandardIn dataUsingEncoding:NSUTF8StringEncoding] : nil) outData:&outData errorData:&errorData];
	if([outData length])
	self.outputStandardOut = [[[NSString alloc] initWithBytes:[outData bytes] length:([outData length] - 1) encoding:NSUTF8StringEncoding] autorelease];
	else
	self.outputStandardOut = @"";
	if([errorData length])
	self.outputStandardError = [[[NSString alloc] initWithBytes:[errorData bytes] length:([errorData length] - 1) encoding:NSUTF8StringEncoding] autorelease];
	else
	self.outputStandardError = @"";
	
	/* Destroy task */
	[task release];
	
	return YES;
}

@end
