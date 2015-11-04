/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import <mach-o/dyld.h>

#import "FreeFrameHostPlugIn.h"

#define	kQCPlugIn_Name				@"FreeFrame Host"
#define	kQCPlugIn_Description		@"Hosts FreeFrame plug-ins inside Quartz Composer"

static CFMutableDictionaryRef		_plugInList = NULL;

@interface FreeFrameHostPlugIn (Internal)
- (void) setPlugInID:(unsigned int)plugInID;
@end

@implementation FreeFrameHostPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic outputImage;

/* We need to synthesize the "plugInID" property */
@synthesize plugInID=_plugInID;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"outputImage"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a processor */
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
	return [NSArray arrayWithObject:@"plugInID"];
}

- (id) init
{
	/* Allocate internal stuff */
	if(self = [super init]) {
		_parameterPorts = [NSMutableArray new];
		_instanceIdentifier = FF_FAIL;
	}
	
	return self;
}

- (void) dealloc
{
	/* Reset currently selected FreeFrame plug-in */
	[self setPlugInID:0];
	
	/* Release internal stuff */
	[_parameterPorts release];
	
	[super dealloc];
}

- (void) setPlugInID:(unsigned int)plugInID
{
	PlugInInfo*						info = (plugInID ? (PlugInInfo*)CFDictionaryGetValue(_plugInList, (const void*)plugInID) : NULL);
	int								numParameters,
									i;
	void*							value;
	NSString*						key;
	NSMutableDictionary*			attributes;
	
	/* De-initialize current FreeFrame plug-in and remove custom input ports */
	if(_info) {
		pthread_mutex_lock(&_info->mutex);
		
		if(_instanceIdentifier != FF_FAIL) {
			(*_info->functionPtr)(FF_DEINSTANTIATE, 0, _instanceIdentifier);
			_instanceIdentifier = FF_FAIL;
		}
		
		if(_info->isSource) {
			[self removeInputPortForKey:@"inputWidth"];
			[self removeInputPortForKey:@"inputHeight"];
		}
		else
		[self removeInputPortForKey:@"inputImage"];
		for(i = 0; i < [_parameterPorts count]; ++i) {
			key = [_parameterPorts objectAtIndex:i];
			if(key != (NSString*)[NSNull null])
			[self removeInputPortForKey:key];
		}
		[_parameterPorts removeAllObjects];
		
		_info->count -= 1;
		if(_info->count == 0)
		(*_info->functionPtr)(FF_DEINITIALISE, 0, 0);
		
		pthread_mutex_unlock(&_info->mutex);
	}
	
	/* Update selected FreeFrame plug-in */
	_plugInID = plugInID;
	_info = info;
	
	/* Initialize current FreeFrame plug-in and add custom input ports */
	if(_info) {
		pthread_mutex_lock(&_info->mutex);
		
		if((_info->count == 0) & ((*_info->functionPtr)(FF_INITIALISE, 0, 0) != FF_SUCCESS)) {
			pthread_mutex_unlock(&_info->mutex);
			return;
		}
		_info->count += 1;
		
		if(_info->isSource) {
			[self addInputPortWithType:QCPortTypeIndex forKey:@"inputWidth" withAttributes:[NSDictionary dictionaryWithObject:@"Pixels Wide" forKey:QCPortAttributeNameKey]];
			[self addInputPortWithType:QCPortTypeIndex forKey:@"inputHeight" withAttributes:[NSDictionary dictionaryWithObject:@"Pixels High" forKey:QCPortAttributeNameKey]];
		}
		else
		[self addInputPortWithType:QCPortTypeImage forKey:@"inputImage" withAttributes:[NSDictionary dictionaryWithObject:@"Image" forKey:QCPortAttributeNameKey]];
		
		numParameters = (int)(*_info->functionPtr)(FF_GETNUMPARAMETERS, 0, 0);
		for(i = 0; i < numParameters; ++i) {
			if(value = (*_info->functionPtr)(FF_GETPARAMETERNAME, (void*)i, 0))
			attributes = [NSMutableDictionary dictionaryWithObject:[[[NSString alloc] initWithBytes:value length:16 encoding:NSASCIIStringEncoding] autorelease] forKey:QCPortAttributeNameKey];
			else
			attributes = [NSMutableDictionary dictionary];
			key = [NSString stringWithFormat:@"param-%i", i];
			
			value = (*_info->functionPtr)(FF_GETPARAMETERTYPE, (void*)i, 0);
			if(value == (void*)FF_FAIL)
			value = (void*)FF_TYPE_STANDARD;
			switch((int)value) {
				
				case FF_TYPE_BOOLEAN:
				case FF_TYPE_EVENT:
				value = (*_info->functionPtr)(FF_GETPARAMETERDEFAULT, (void*)i, 0);
				[attributes setObject:[NSNumber numberWithBool:(*((float*)&value) ? YES : NO)] forKey:QCPortAttributeDefaultValueKey];
				[self addInputPortWithType:QCPortTypeBoolean forKey:key withAttributes:attributes];
				[_parameterPorts addObject:key];
				break;
				
				case FF_TYPE_RED:
				case FF_TYPE_GREEN:
				case FF_TYPE_BLUE:
				case FF_TYPE_STANDARD:
				case FF_TYPE_XPOS:
				case FF_TYPE_YPOS:
				[attributes setObject:[NSNumber numberWithDouble:0.0] forKey:QCPortAttributeMinimumValueKey];
				[attributes setObject:[NSNumber numberWithDouble:1.0] forKey:QCPortAttributeMaximumValueKey];
				[self addInputPortWithType:QCPortTypeNumber forKey:key withAttributes:attributes];
				[_parameterPorts addObject:key];
				break;
				
				case FF_TYPE_TEXT:
				if(value = (*_info->functionPtr)(FF_GETPARAMETERDEFAULT, (void*)i, 0))
				[attributes setObject:[[[NSString alloc] initWithBytes:value length:strlen(value) encoding:NSASCIIStringEncoding] autorelease] forKey:QCPortAttributeDefaultValueKey];
				[self addInputPortWithType:QCPortTypeString forKey:key withAttributes:attributes];
				[_parameterPorts addObject:key];
				break;
				
				default:
				[_parameterPorts addObject:[NSNull null]];
				break;
				
			}
		}
		
		pthread_mutex_unlock(&_info->mutex);
	}
}

- (QCPlugInViewController*) createViewController
{
	/* Create a QCPlugInViewController to handle the user-interface to edit the our internal settings */
	return [[FreeFrameHostViewController alloc] initWithPlugIn:self viewNibName:@"FreeFrameHostSettings"];
}

@end

@implementation FreeFrameHostPlugIn (Execution)

static void _BufferReleaseCallback(const void* address, void* context)
{
	free((void*)address);
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	static CGColorSpaceRef			colorSpace = NULL;
	BOOL							success = NO;
	id<QCPlugInInputImageSource>	sourceImage;
	unsigned						width,
									height;
	void*							pixelBuffer;
	unsigned						rowWidth,
									rowLength,
									srcRowBytes,
									dstRowBytes;
	char*							srcAddress;
	char*							dstAddress;
	ProcessFrameCopyStruct			frameInfo;
	int								result,
									i;
	SetParameterStruct				parameterInfo;
	id								provider;
	NSString*						key;
	id								value;
	
	/* Make sure a FreeFrame plug-in is selected */
	if(_info == NULL)
	return NO;
	
	/* Retrieve source image if any as well frame dimensions */
	if(_info->isSource) {
		width = [[self valueForInputKey:@"inputWidth"] unsignedIntValue];
		height = [[self valueForInputKey:@"inputHeight"] unsignedIntValue];
		if(!width || !height) {
			self.outputImage = nil;
			return YES;
		}
		
		sourceImage = nil;
	}
	else {
		sourceImage = [self valueForInputKey:@"inputImage"];
		if(sourceImage == nil) {
			self.outputImage = nil;
			return YES;
		}
		
		if(![sourceImage lockBufferRepresentationWithPixelFormat:QCPlugInPixelFormatARGB8 colorSpace:[context colorSpace] forBounds:[sourceImage imageBounds]])
		return NO;
		width = [sourceImage bufferPixelsWide];
		height = [sourceImage bufferPixelsHigh];
	}
	
	/* Since FreeFrame plug-ins do not support customized bytes-per-row, we emulate it through an adjusted frame width (which must be a multiple of 4) */
	rowWidth = width;
	if(rowWidth % 4)
	rowWidth = (rowWidth / 4 + 1) * 4;
	
	/* Instantiate FreeFrame plug-in */
	if((_instanceIdentifier != FF_FAIL) && ((_instanceInfo.frameWidth != rowWidth) || (_instanceInfo.frameHeight != height))) {
		pthread_mutex_lock(&_info->mutex);
		(*_info->functionPtr)(FF_DEINSTANTIATE, 0, _instanceIdentifier);
		pthread_mutex_unlock(&_info->mutex);
		_instanceIdentifier = FF_FAIL;
	}
	if(_instanceIdentifier == FF_FAIL) {
		_instanceInfo.frameWidth = rowWidth;
		_instanceInfo.frameHeight = height;
		_instanceInfo.bitDepth = 2; //32 bits
		_instanceInfo.orientation = 2; //bottom-left
		pthread_mutex_lock(&_info->mutex);
		_instanceIdentifier = (int)(*_info->functionPtr)(FF_INSTANTIATE, &_instanceInfo, 0);
		pthread_mutex_unlock(&_info->mutex);
		if(_instanceIdentifier == FF_FAIL)
		return NO;
	}

	/* Lock */
	pthread_mutex_lock(&_info->mutex);
	
	/* Set FreeFrame plug-in parameters */
	for(i = 0; i < [_parameterPorts count]; ++i) {
		key = [_parameterPorts objectAtIndex:i];
		if(key == (NSString*)[NSNull null])
		continue;
		value = [self valueForInputKey:key];
		
		parameterInfo.index = i;
		if([value isKindOfClass:[NSString class]]) {
			result = (int)[value UTF8String];
			parameterInfo.value = *((float*)&result);
		}
		else if([value isKindOfClass:[NSNumber class]]) {
			parameterInfo.value = [value doubleValue];
		}
		else {
			pthread_mutex_unlock(&_info->mutex);
			[sourceImage unlockBufferRepresentation];
			return NO;
		}
		
		result = (int)(*_info->functionPtr)(FF_SETPARAMETER, &parameterInfo, _instanceIdentifier);
		if(result != FF_SUCCESS) {
			pthread_mutex_unlock(&_info->mutex);
			[sourceImage unlockBufferRepresentation];
			return NO;
		}
	}
	
	/* Allocated output buffer */
	rowLength = rowWidth * 4;
	pixelBuffer = valloc(height * rowLength);
	if(pixelBuffer == NULL) {
		pthread_mutex_unlock(&_info->mutex);
		[sourceImage unlockBufferRepresentation];
		return NO;
	}
	
	/* Perform processing - We can only do a frame copy if the plug-in supports it and the source buffer bytes-per-row is equal to the destination buffer bytes-per-row */
	if(sourceImage && _info->supportsFrameCopy && ([sourceImage bufferBytesPerRow] == rowLength)) {
		srcAddress = (char*)[sourceImage bufferBaseAddress];
		frameInfo.numInputFrames = 1;
		frameInfo.InputFrames = (void**)&srcAddress;
		frameInfo.OutputFrame = pixelBuffer;
		result = (int)(*_info->functionPtr)(FF_PROCESSFRAMECOPY, &frameInfo, _instanceIdentifier);
	}
	else {
		if(sourceImage) {
			srcAddress = (char*)[sourceImage bufferBaseAddress];
			srcRowBytes = [sourceImage bufferBytesPerRow];
			dstAddress = pixelBuffer;
			dstRowBytes = rowLength;
			for(i = 0; i < height; ++i) {
				bcopy(srcAddress, dstAddress, width * 4);
				srcAddress += srcRowBytes;
				dstAddress += dstRowBytes;
			}
		}
		result = (int)(*_info->functionPtr)(FF_PROCESSFRAME, pixelBuffer, _instanceIdentifier);
	}
	
	/* Unlock */
	pthread_mutex_unlock(&_info->mutex);
	
	/* Create an image provider from output buffer on success */
	if((result == FF_SUCCESS) && (provider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatARGB8 pixelsWide:width pixelsHigh:height baseAddress:pixelBuffer bytesPerRow:rowLength releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES])) {
		self.outputImage = provider;
		success = YES;
	}
	else
	free(pixelBuffer);
	
	/* Clean up */
	[sourceImage unlockBufferRepresentation];
	
	return success;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* Destroy FreeFrame plug-in instance */
	if(_instanceIdentifier != FF_FAIL) {
		pthread_mutex_lock(&_info->mutex);
		(*_info->functionPtr)(FF_DEINSTANTIATE, 0, _instanceIdentifier);
		pthread_mutex_unlock(&_info->mutex);
		
		_instanceIdentifier = FF_FAIL;
	}
}

@end

@implementation FreeFrameHostViewController

static void _AddToMenuApplierFunction(const void* key, const void* value, void* context)
{
	PlugInInfo*							infoPtr = (PlugInInfo*)value;
	
	/* Add a menu entry */
	[(NSPopUpButton*)context addItemWithTitle:infoPtr->name];
	[[(NSPopUpButton*)context lastItem] setRepresentedObject:[NSNumber numberWithUnsignedInt:infoPtr->uniqueID]];
}

- (void) loadView
{
	[super loadView];
	
	/* Populate the menu */
	[plugInMenu setAutoenablesItems:NO];
	[plugInMenu removeAllItems];
	CFDictionaryApplyFunction(_plugInList, _AddToMenuApplierFunction, plugInMenu);
	
	/* Reflect currently selected FreeFrame plug-in */
	[plugInMenu selectItemAtIndex:[plugInMenu indexOfItemWithRepresentedObject:[[self plugIn] valueForKey:@"plugInID"]]];
}

- (IBAction) selectPlugIn:(id)sender
{
	/* Update select FreeFrame plug-in */
	[[self plugIn] setValue:[[plugInMenu selectedItem] representedObject] forKey:@"plugInID"];
}

@end

@implementation FreeFrameHostPlugIn (Registry)

+ (FF_Main_FuncPtr) loadFreeFramePlugInAtPath:(NSString*)path
{
	NSURL*						url;
	FF_Main_FuncPtr				functionPtr;
	CFBundleRef					bundle;
	
	url = [NSURL fileURLWithPath:path];
	if(url == nil)
	return NULL;
	
	bundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)url);
	if(bundle == NULL)
	return NULL;
	if(!CFBundleLoadExecutable(bundle)) {
		CFRelease(bundle);
		return NULL;
	}
	
	functionPtr = CFBundleGetFunctionPointerForName(bundle, CFSTR("plugMain"));
	if(functionPtr == NULL) {
		CFRelease(bundle);
		return NULL;
	}
	
	return functionPtr;
}

+ (BOOL) registerFreeFramePlugInAtPath:(NSString*)path
{
	FF_Main_FuncPtr				functionPtr;
	PlugInInfo*					info;
	PlugInfoStruct*				infoPtr;
	PlugExtendedInfoStruct*		extendedInfoPtr;
	
	functionPtr = [self loadFreeFramePlugInAtPath:path];
	if(functionPtr == NULL)
	return NO;
	
	if((*functionPtr)(FF_GETPLUGINCAPS, (void*)FF_CAP_32BITVIDEO, 0) == 0)
	return NO;
	infoPtr = (*functionPtr)(FF_GETINFO, 0, 0);
	if((infoPtr == NULL) || ((infoPtr->pluginType != 0) && (infoPtr->pluginType != 1)))
	return NO;
	
	info = calloc(1, sizeof(PlugInInfo));
	pthread_mutex_init(&info->mutex, NULL);
	info->functionPtr = functionPtr;
	bcopy(infoPtr->uniqueID, &info->uniqueID, 4);
	info->isSource = (infoPtr->pluginType == 1 ? YES : NO);
	if(infoPtr->pluginName)
	info->name = [[NSString alloc] initWithBytes:infoPtr->pluginName length:16 encoding:NSASCIIStringEncoding];
	else
	info->name = [[NSString alloc] initWithBytes:infoPtr->uniqueID length:4 encoding:NSASCIIStringEncoding];
	if(extendedInfoPtr = (*info->functionPtr)(FF_GETEXTENDEDINFO, 0, 0)) {
		if(extendedInfoPtr->Description)
		info->description = [[NSString alloc] initWithBytes:extendedInfoPtr->Description length:strlen(extendedInfoPtr->Description) encoding:NSASCIIStringEncoding];
		if(extendedInfoPtr->About)
		info->copyright = [[NSString alloc] initWithBytes:extendedInfoPtr->About length:strlen(extendedInfoPtr->About) encoding:NSASCIIStringEncoding];
	}
	if((*functionPtr)(FF_GETPLUGINCAPS, (void*)FF_CAP_PROCESSFRAMECOPY, 0) != 0)
	info->supportsFrameCopy = YES;
	
	CFDictionarySetValue(_plugInList, (const void*)info->uniqueID, info);
	
	return YES;
}

+ (void) registerFreeFramePlugInsAtPath:(NSString*)path
{
	NSDirectoryEnumerator*				enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
	NSString*							item;
	
	while(item = [enumerator nextObject]) {
		[enumerator skipDescendents];
		if([item characterAtIndex:0] == '.')
		continue;
		if(![[item pathExtension] isEqualToString:@"frf"])
		continue;
		
		if(![self registerFreeFramePlugInAtPath:[path stringByAppendingPathComponent:item]])
		NSLog(@"Failed registering FreeFrame plug-in at path \"%@\"", [path stringByAppendingPathComponent:item]);
	}
}

+ (void) initialize
{
	if(_plugInList == NULL) {
		_plugInList = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
		
		[self registerFreeFramePlugInsAtPath:@"/Library/Graphics/FreeFrame Plug-Ins"];
		[self registerFreeFramePlugInsAtPath:[@"~/Library/Graphics/FreeFrame Plug-Ins" stringByExpandingTildeInPath]];
	}
}

@end
