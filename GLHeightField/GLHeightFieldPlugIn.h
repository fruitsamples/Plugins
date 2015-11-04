#import <Quartz/Quartz.h>
#import <OpenGL/gl.h>

@interface GLHeightFieldPlugIn : QCPlugIn
{
	GLuint*			_indices;
	GLuint			_renderBuffer,
					_frameBuffer,
					_vertexBuffer;
}

/* Declare a property input port of type "Image" and with the key "inputImage" */
@property(assign) id<QCPlugInInputImageSource> inputImage;

/* Declare a property input port of type "Color" and with the key "inputColor" */
@property(assign) CGColorRef inputColor;

/* Declare a property input port of type "Boolean" and with the key "inputWireFrame" */
@property BOOL inputWireFrame;

@end
