/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "GLSquarePlugIn.h"

#define	kQCPlugIn_Name				@"OpenGL Square"
#define	kQCPlugIn_Description		@"Renders a colored square"

@implementation GLSquarePlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputX, inputY, inputColor, inputImage;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputX"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"X Position", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"inputY"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Y Position", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"inputColor"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Color", QCPortAttributeNameKey, nil];
	if([key isEqualToString:@"inputImage"])
	return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a consumer (it renders graphics using OpenGL) */
	return kQCPlugInExecutionModeConsumer;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) */
	return kQCPlugInTimeModeNone;
}

@end

@implementation GLSquarePlugIn (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CGLContextObj					cgl_ctx = [context CGLContextObj];
	id<QCPlugInInputImageSource>	image;
	GLuint							textureName;
	GLint							saveMode,
									saveName;
	GLboolean						saveEnabled;
	const CGFloat*					colorComponents;
	GLenum							error;
	
	if(cgl_ctx == NULL)
	return NO;
	
	/* Copy the image on the "inputImage" input port to a local variable */
	image = self.inputImage;
	
	/* Get a texture from the image in the context colorspace */
	if(image && [image lockTextureRepresentationWithColorSpace:([image shouldColorMatch] ? [context colorSpace] : [image imageColorSpace]) forBounds:[image imageBounds]])
	textureName = [image textureName];
	else
	textureName = 0;
	
	/* Save and set modelview matrix */
	glGetIntegerv(GL_MATRIX_MODE, &saveMode);
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glTranslatef(self.inputX, self.inputY, 0.0);
	
	/* Bind texture to unit */
	if(textureName)
	[image bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
		
	/* Get RGBA components from the color on the "inputColor" input port (the CGColorRef is guaranteed to be of type RGBA) */
	colorComponents = CGColorGetComponents(self.inputColor);
	
	/* Set current color (no need to save / restore as the current color is part of the GL_CURRENT_BIT) */
	glColor4f(colorComponents[0], colorComponents[1], colorComponents[2], colorComponents[3]);
	
	/* Render textured quad (we can use normalized texture coordinates independently of the texture target or the texture vertical flipping state thanks to -bindTextureRepresentationToCGLContext) */
	glBegin(GL_QUADS);
		glTexCoord2f(1.0, 1.0);
		glVertex3f(0.5, 0.5, 0);
		glTexCoord2f(0.0, 1.0);
		glVertex3f(-0.5, 0.5, 0);
		glTexCoord2f(0.0, 0.0);
		glVertex3f(-0.5, -0.5, 0);
		glTexCoord2f(1.0, 0.0);
		glVertex3f(0.5, -0.5, 0);
	glEnd();
	
	/* Unbind texture from unit */
	if(textureName)
	[image unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE0];
	
	/* Restore modelview matrix */
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(saveMode);
	
	/* Check for OpenGL errors */
	if(error = glGetError())
	[context logMessage:@"OpenGL error %04X", error];
	
	/* Release texture */
	if(textureName)
	[image unlockTextureRepresentation];
	
	return (error ? NO : YES);
}

@end
