#import "OpticalFlow_DownloaderPlugIn.h"

#define	kQCPlugIn_Name				@"Optical Flow Downloader"
#define	kQCPlugIn_Description		@"Converts an optical flow image buffer to a structure containing each of the velocity vectors coordinates"

@implementation OpticalFlow_DownloaderPlugIn

@dynamic inputImage, outputVelocities;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (QCPlugInTimeMode) timeMode
{
	return kQCPlugInTimeModeNone;
}

@end

@implementation OpticalFlow_DownloaderPlugIn (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	float*				baseAddress;
	// Colorspace must be RGBLinear so that they are not transformed and negative values are preserved
	CGColorSpaceRef		colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
	NSUInteger			width,
						height, 
						floatsPerRow,
						x, y;
	float				u, v;
	NSRect				bounds = [self.inputImage imageBounds];
	CFMutableArrayRef	uArray, vArray;
	CFNumberRef			number;
	
	// Downloading image
	[self.inputImage lockBufferRepresentationWithPixelFormat:QCPlugInPixelFormatRGBAf colorSpace:colorSpace forBounds:bounds];
	
	// Getting image info
	baseAddress = (float*)[self.inputImage bufferBaseAddress];
	width = [self.inputImage bufferPixelsWide];
	height = [self.inputImage bufferPixelsHigh];
	floatsPerRow = [self.inputImage bufferBytesPerRow]/sizeof(float);
	
	// Creating coordinate arrays
	uArray = CFArrayCreateMutable(kCFAllocatorDefault, width*height, &kCFTypeArrayCallBacks);
	vArray = CFArrayCreateMutable(kCFAllocatorDefault, width*height, &kCFTypeArrayCallBacks);
		
	// We read each image pixel and store its R and G value in the arrays (corresponding to u and v respectively)
	for (y=0; y<height; ++y) {
		for (x=0; x<width; ++x) {
			u = -baseAddress[4*x+y*floatsPerRow];
			v = -baseAddress[4*x+1+y*floatsPerRow];
			number = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &u);
			CFArrayAppendValue(uArray, number);
			CFRelease(number);
			number = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &v);
			CFArrayAppendValue(vArray, number);
			CFRelease(number);
		}
	}
	
	[self.inputImage unlockBufferRepresentation];

	self.outputVelocities = [NSDictionary dictionaryWithObjectsAndKeys:(id)uArray, @"u", (id)vArray, @"v", nil];
	
	CFRelease(colorSpace);
	
	return YES;
}

@end
