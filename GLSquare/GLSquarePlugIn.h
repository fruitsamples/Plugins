#import <Quartz/Quartz.h>

@interface GLSquarePlugIn : QCPlugIn
{
}

/* Declare two property input ports of type "Number" and with the key "inputX" and "inputY" */
@property double inputX;
@property double inputY;

/* Declare a property input port of type "Color" and with the key "inputColor" */
@property(assign) CGColorRef inputColor;

/* Declare a property input port of type "Image" and with the key "inputImage" */
@property(assign) id<QCPlugInInputImageSource> inputImage;

@end
