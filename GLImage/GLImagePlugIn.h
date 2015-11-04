#import <Quartz/Quartz.h>

/* Set this to 1 to use a custom <QCPlugInOutputImageProvider> class instead of the convenience method -outputImageProviderFromTextureWithPixelFormat */
#define __USE_PROVIDER__ 1

/* Set this to 1 to implement the -copyRenderedTextureForCGLContext API instead of the -renderWithCGLContext one in the QCPlugInOutputImageProvider class */
#if __USE_PROVIDER__
#define __USE_RENDERED_TEXTURES__ 0
#endif

@interface GLImagePlugIn : QCPlugIn
{
}

/* Declare a property input port of type "Index" and with the key "inputWidth" */
@property NSUInteger inputWidth;

/* Declare a property input port of type "Color" and with the key "inputHeight" */
@property NSUInteger inputHeight;

/* Declare a property input port of type "Color" and with the key "inputStartColor" */
@property(assign) CGColorRef inputStartColor;

/* Declare a property input port of type "Color" and with the key "inputEndColor" */
@property(assign) CGColorRef inputEndColor;

/* Declare a property output port of type "Image" and with the key "outputGradientImage" */
@property(assign) id<QCPlugInOutputImageProvider> outputGradientImage;

@end

#if __USE_PROVIDER__

/* This internal class represents the images this plug-in produces */
@interface GLImage : NSObject <QCPlugInOutputImageProvider>
{
	CGColorSpaceRef					_colorSpace;
	NSUInteger						_width,
									_height;
	CGFloat							_topColor[4], //RGBA
									_bottomColor[4]; //RGBA
}
- (id) initWithColorSpace:(CGColorSpaceRef)colorSpace pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height topColor:(CGColorRef)topColor bottomColor:(CGColorRef)bottomColor;
@end

#endif
