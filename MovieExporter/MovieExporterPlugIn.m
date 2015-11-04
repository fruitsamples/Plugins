#import "MovieExporterPlugIn.h"

#define	kQCPlugIn_Name				@"Movie Exporter"
#define	kQCPlugIn_Description		@"Exports images using a background thread to a Quicktime file on disk"

// INTERFACE:

@interface MovieExporterPlugIn(Internal)
- (void) _processRequest;
@end

// FUNCTIONS:

/* Converts an relative to an absolute path */
static NSString* ConvertRelativeToAbsolutePath(id context, NSString* path)
{
	NSURL*		url;
	
	if([path length]) {
		if([path characterAtIndex:0] == '~')
		path = [path stringByExpandingTildeInPath];
		else if(([path characterAtIndex:0] != '/') && (url = [context compositionURL]) && [url isFileURL])
		return [[[url path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:path];
	}
	return path;
}

/* Converts an index from interface to quality parameter for QTKit */
static NSUInteger _CodecQualityConvert(NSUInteger i)
{
	switch (i) {
		case 0: return codecMinQuality;
		case 1: return codecLowQuality;
		case 2: return codecNormalQuality;
		case 3: return codecHighQuality;
		case 4: return codecMaxQuality;
		case 5: return codecLosslessQuality;
	}
	return 0;
}

/* Callback performed by source of background thread which calls the _processRequest function on the plug-in. */
static void _SourcePerformCallBack(void* info)
{
	NSAutoreleasePool*			pool = [NSAutoreleasePool new];

	[(MovieExporterPlugIn*)(void*)info _processRequest];
	
	[pool drain];
}

// IMPLEMENTATION:

@implementation MovieExporterPlugIn

@dynamic inputExport, inputExportPath, inputImage;

+ (NSDictionary*) attributes
{
	/* Return a dictionary of attributes describing the plug-in */	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputExport"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Export Signal", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"inputExportPath"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Movie Location", QCPortAttributeNameKey, @"~/Movies/MyMovie.mov", QCPortAttributeDefaultValueKey, nil];
	if([key isEqualToString:@"inputImage"])
	return [NSDictionary dictionaryWithObject:@"Image" forKey:QCPortAttributeNameKey];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a consumer (it renders to a movie file) */	
	return kQCPlugInExecutionModeConsumer;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) */
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	NSDictionary*			codecInfo;
	
	if(self = [super init]) {
		/* Load Codecs.plist containing a list of codecs. Need other codecs? ImageCompression.h in Quicktime Framework */
		codecInfo = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[MovieExporterPlugIn class]] pathForResource:@"Codecs" ofType:@"plist"]];
		
		/* List of codec names and keys */
		_codecTypes = [[codecInfo valueForKey:@"CodecTypes"] retain];
		_codecKeys = [[codecInfo valueForKey:@"CodecKeys"] retain];
		
		/* Finish intialization */
		pthread_mutex_init(&_threadMutex, NULL);
		pthread_cond_init(&_threadCondition, NULL);
		_previousDuration = QTZeroTime;
		_time = -1.;
		_codecIndex = 12; //MPEG4 by default
		_codecQuality = 3; //Medium Quality
	}
	
	return self;
}

- (void) finalize_thread
{
	/* Destroy variables intialized in init and not released by GC */
	pthread_mutex_destroy(&_threadMutex);
	pthread_cond_destroy(&_threadCondition);
}

- (void) finalize
{
	/* Destroy variables intialized in init and not released by GC */
	[self finalize_thread];

	[super finalize];
}

- (void) dealloc
{
	/* Release any resources created in -init. */
	[_codecTypes release];
	[_codecKeys release];
	[self finalize_thread];

	[super dealloc];
}

+ (NSArray*) plugInKeys
{
	/* Return a list of the KVC keys corresponding to the internal settings of the plug-in. */	
	return [NSArray arrayWithObjects:@"codecIndex", @"codecQuality", nil];
}

- (QCPlugInViewController*) createViewController
{
	/* Return a new QCPlugInViewController to edit the internal settings of this plug-in instance. */	
	return [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"MovieExporterSettings"];
}

@end

@implementation MovieExporterPlugIn (Execution)

/* This is where the thread processes the frame and adds it to the movie */
- (void) _processRequest
{
	pthread_mutex_lock(&_threadMutex);
	
	/* Add _previousImage (for which the _previousDuration is known) to the movie file, using codec and compression quality as defined in the settings pane (bound to _codecIndex) */
	[_movie addImage:_previousImage forDuration:_previousDuration withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[_codecKeys objectAtIndex:_codecIndex],
														QTAddImageCodecType,
														[NSNumber numberWithLong:_CodecQualityConvert(_codecQuality)],
														QTAddImageCodecQuality,
														nil]];
	/* Send signal that frame has been processed */
	[(id)_previousImage release];
	_previousImage = nil;
	
	/* Release buffer representation */
	[_previousQCImage unlockBufferRepresentation];
	[(id)_previousQCImage release];
	_previousQCImage = nil;

	/* Send signal that frame has been processed */
	pthread_cond_signal(&_threadCondition, &_threadMutex);
	pthread_mutex_unlock(&_threadMutex);
}

/* This is where the thread starts and creates its source for processing frames */
- (void) _processingThread:(id)userInfo
{
	void*						info = self;
	CFRunLoopSourceContext		context = {0, info, NULL, NULL, NULL, NULL, NULL, NULL, NULL, _SourcePerformCallBack};
	NSAutoreleasePool*			pool;
	
	pool = [NSAutoreleasePool new];	
	
	/* Threading calls for QTKit */ 
	[QTMovie enterQTKitOnThread];
	[_movie attachToCurrentThread];
	
	/* Get the current _runLoop */ 
	_runLoop = CFRunLoopGetCurrent();
	
	/* Send signal that the thread has started */
	pthread_mutex_lock(&_threadMutex);
	pthread_cond_signal(&_threadCondition);
	pthread_mutex_unlock(&_threadMutex);	
	
	[pool drain];
	
	if (_runLoop) {
		/* Creating the source, associated with _SourcePerformCallBack callback */
		_source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
		if (!_source)
		NSLog (@"Error creating source in thread: later calls will fail");
		CFRunLoopAddSource(CFRunLoopGetCurrent(), _source, kCFRunLoopDefaultMode);
		
		/* Starting the run loop */
		CFRunLoopRun();
		
		/* Releasing the source */
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _source, kCFRunLoopDefaultMode);
		CFRelease(_source);
	}
	
	/* Threading calls for QTKit */ 
	[_movie detachFromCurrentThread];
	[QTMovie exitQTKitOnThread];
	
	/* Send signal that the thread has stopped */
	pthread_mutex_lock(&_threadMutex);
	_runLoop = NULL;
	pthread_cond_signal(&_threadCondition);
	pthread_mutex_unlock(&_threadMutex);
}

- (void) _destroyThread
{
	/* Ask the thread to terminate */
	pthread_mutex_lock(&_threadMutex);
	if(_runLoop) {
		CFRunLoopStop(_runLoop);
		pthread_cond_wait(&_threadCondition, &_threadMutex);
	}
	pthread_mutex_unlock(&_threadMutex);
}

- (void) _reset
{
	/* Destroy thread and reset variables */
	[self _destroyThread];
	if (_previousImage) {
		[_previousImage release];
		_previousImage = nil;
	}
	if (_currentImage) {
		[_currentImage release];
		_currentImage = nil;
	}
	[_movie release];
	_movie = nil;
	_time = -1;
	_previousDuration = QTZeroTime;	
}

- (BOOL) _setupThread
{
	/* Lauch thread */
	pthread_mutex_lock(&_threadMutex);
	[NSThread detachNewThreadSelector:@selector(_processingThread:) toTarget:self withObject:nil];
	pthread_cond_wait(&_threadCondition, &_threadMutex);
	pthread_mutex_unlock(&_threadMutex);
	
	return _runLoop ? YES : NO;
}

- (void) _queueImage:(id<QCPlugInInputImageSource>)image
{
	NSImage*							nsImage = nil;
	NSBitmapImageRep*					bitmapRep;
	unsigned char*						baseAddress;
	NSTimeInterval						currentTime;
	
	/* Get the current time so that we know how long the *previous* image stayed on screen */
	currentTime = [NSDate timeIntervalSinceReferenceDate];
	if (_time < 0.)
	_time = currentTime;
	else
	_previousDuration = QTMakeTimeWithTimeInterval(currentTime - _time);
		
	if (image) {
		/* Get a buffer representation from the image in its native colorspace */
		[image lockBufferRepresentationWithPixelFormat:QCPlugInPixelFormatARGB8 colorSpace:[image imageColorSpace] forBounds:[image imageBounds]];
		
		/* We create a NSBitmapImageRep representation from the buffer representation. It does not own the bytes, so we're responsible of keeping them around and releasing them when necessary, by releasing the buffer representation */
		baseAddress = (unsigned char*)[image bufferBaseAddress];
		bitmapRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&baseAddress pixelsWide:[image bufferPixelsWide] pixelsHigh:[image bufferPixelsHigh] bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:NSAlphaFirstBitmapFormat bytesPerRow:[image bufferBytesPerRow] bitsPerPixel: 32];	
		
		/* NSImage out of the NSBitmapImageRep */
		nsImage = [[NSImage alloc] initWithSize:NSMakeSize([image bufferPixelsWide], [image bufferPixelsHigh])];
		[nsImage addRepresentation:bitmapRep];
		[bitmapRep release];	
		
	}
	
	/* We wait for the background thread to have added _previousImage to the movie */
	pthread_mutex_lock(&_threadMutex);
	if (_previousImage != nil)
	pthread_cond_wait(&_threadCondition, &_threadMutex);

	/* We update current image with the new image, and _previousImage with _currentImage
	   We retain each associated QC Image, so that we can release the buffer representation later on. */
	_previousImage = _currentImage;
	_previousQCImage = _currentQCImage;
	_currentImage = nsImage;
	_currentQCImage = [(id)image retain];
	
	pthread_mutex_unlock(&_threadMutex);
		
	/* We wake up the background thread so that it deals with _previousImage */
	CFRunLoopSourceSignal(_source);
	CFRunLoopWakeUp(_runLoop);
	
	_time = currentTime;	
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	if ([self didValueForInputKeyChange:@"inputExport"] || [self didValueForInputKeyChange:@"inputExportPath"]) {
		if (_runLoop) {
			/* Add the last image to the movie if necessary */
			if (_currentImage) {
				[self _queueImage:nil];
				pthread_mutex_lock(&_threadMutex);
				if (_previousImage)
				pthread_cond_wait(&_threadCondition, &_threadMutex);
				pthread_mutex_unlock(&_threadMutex);
			}
			/* Stop thread */
			[self _destroyThread];

			/* Complete writing movie to disk */
			[_movie attachToCurrentThread];
			[_movie updateMovieFile];
			
			/* Reset parameters */
			[_movie release];
			_movie = nil;
			_time = -1;
			_previousDuration = QTZeroTime;	
		}
		
		if (self.inputExport) {
			/* Allocate movie with path from "inputExport" input port */
			_movie = [[QTMovie alloc] initToWritableFile:ConvertRelativeToAbsolutePath(context, self.inputExportPath) error:nil];
			
			if (_movie) {
				[_movie detachFromCurrentThread];
			
				/* Start background thread */
				if (![self _setupThread]) {
					[_movie release];
					_movie = nil;
				}
				else {
					/* When starting to record after an image as been set on the "inputImage" input port, we still want that image to be added as soon as "inputExport" input port is YES */
					if (![self didValueForInputKeyChange:@"inputImage"] && self.inputImage)
					[self _queueImage:self.inputImage];
				}
			}
		}
	}
	
	/* When "inputExport" input port is YES, we queue images so that there's added to the movie by background thread */
	if (self.inputExport) {
		if (!_runLoop) {
			NSLog (@"Could not render movie file. Maybe the file is locked by another process.");
			return NO;
		}
		else if ([self didValueForInputKeyChange:@"inputImage"])
		[self _queueImage:self.inputImage];
	}
	
	return YES;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in. */	
	[self _reset];
}

@end
