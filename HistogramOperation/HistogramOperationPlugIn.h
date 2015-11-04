#import <Quartz/Quartz.h>
#import <Accelerate/Accelerate.h>

/* Set this to 1 to use a custom <QCPlugInOutputImageProvider> class instead of the convenience method -outputImageProviderFromBufferWithPixelFormat */
#define __USE_PROVIDER__ 1

#if __USE_PROVIDER__
@class Histogram;
#endif

@interface HistogramOperationPlugIn : QCPlugIn
{
#if __USE_PROVIDER__
	Histogram*						_cachedHistogram;
#endif
}

/* Declare a property input port of type "Image" and with the key "inputSourceImage" */
@property(assign) id<QCPlugInInputImageSource> inputSourceImage;

/* Declare a property input port of type "Image" and with the key "inputHistogramImage" */
@property(assign) id<QCPlugInInputImageSource> inputHistogramImage;

/* Declare a property output port of type "Image" and with the key "outputResultImage" */
@property(assign) id<QCPlugInOutputImageProvider> outputResultImage;

@end

#if __USE_PROVIDER__

/* This internal class computes lazily an RGBA histogram from an image */
@interface Histogram : NSObject
{
	id<QCPlugInInputImageSource>	_image;
	CGColorSpaceRef					_colorSpace;
	vImagePixelCount				_histogramA[256];
	vImagePixelCount				_histogramR[256];
	vImagePixelCount				_histogramG[256];
	vImagePixelCount				_histogramB[256];
}
- (id) initWithImageSource:(id<QCPlugInInputImageSource>)image colorSpace:(CGColorSpaceRef)colorSpace;
- (BOOL) getRGBAHistograms:(vImagePixelCount**)histograms;
@end

/* This internal class represents the images this plug-in produces */
@interface HistogramImageProvider : NSObject <QCPlugInOutputImageProvider>
{
	id<QCPlugInInputImageSource>	_image;
	Histogram*						_histogram;
}
- (id) initWithImageSource:(id<QCPlugInInputImageSource>)image histogram:(Histogram*)histogram;
@end

#endif
