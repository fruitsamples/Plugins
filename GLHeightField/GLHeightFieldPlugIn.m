/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "GLHeightFieldPlugIn.h"

#define	kQCPlugIn_Name				@"OpenGL Height Field"
#define	kQCPlugIn_Description		@"Renders a 3D height field from an image."

#define kSize						128

@implementation GLHeightFieldPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic inputImage, inputColor, inputWireFrame;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"inputImage"])
	return [NSDictionary dictionaryWithObject:@"Image" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"inputColor"])
	return [NSDictionary dictionaryWithObject:@"Color" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"inputWireFrame"])
	return [NSDictionary dictionaryWithObject:@"Wireframe Mode" forKey:QCPortAttributeNameKey];
	
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

@implementation GLHeightFieldPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	CGLContextObj					cgl_ctx = [context CGLContextObj];
	int								i = 0,
									x,
									y;
	GLenum							error;
	
	if(cgl_ctx == NULL)
	return NO;
	
	/* Create VBO */
	glGenBuffers(1, &_vertexBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
	glBufferData(GL_ARRAY_BUFFER, kSize * kSize * 4 * sizeof(GLfloat), NULL, GL_DYNAMIC_COPY);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	
	/* Create FBO render buffer */
	glGenRenderbuffersEXT(1, &_renderBuffer);
	glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _renderBuffer);
	glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA_FLOAT32_APPLE, kSize, kSize);
	glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, 0);
	
	/* Create FBO */
	glGenFramebuffersEXT(1, &_frameBuffer);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _frameBuffer);
	glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_RENDERBUFFER_EXT, _renderBuffer);
	error = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
	if(error != GL_FRAMEBUFFER_COMPLETE_EXT) {
		glDeleteFramebuffersEXT(1, &_frameBuffer);
		glDeleteTextures(1, &_renderBuffer);
		return NO;
	}
	
	/* Check for OpenGL errors */
	if(error = glGetError()) {
		[context logMessage:@"OpenGL error %04X", error];
		glDeleteFramebuffersEXT(1, &_frameBuffer);
		glDeleteTextures(1, &_renderBuffer);
		return NO;
	}
	
	/* Allocate indices array for VBO */
	_indices = malloc((kSize-1) * (kSize-1) * 6 * sizeof(GLuint));
	if(_indices == NULL) {
		glDeleteFramebuffersEXT(1, &_frameBuffer);
		glDeleteTextures(1, &_renderBuffer);
		return NO;
	}
	for(y = 0; y < kSize - 1; y++) {
		for(x = 0; x < kSize - 1; x++) {
			_indices[i + 0] = x + y * kSize;
			_indices[i + 1] = x + y * kSize + kSize;
			_indices[i + 2] = x + y * kSize + 1;
			_indices[i + 3] = x + y * kSize + 1;
			_indices[i + 4] = x + y * kSize + kSize;
			_indices[i + 5] = x + y * kSize + kSize + 1;
			i += 6;
		}
	}
	
	return YES;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CGLContextObj					cgl_ctx = [context CGLContextObj];
	id<QCPlugInInputImageSource>	image = self.inputImage;
	GLenum							error;
	GLint							viewport[4];
	GLint							saveMode,
									saveName,
									saveModes[2];
	GLboolean						saveEnabled;
	const CGFloat*					colorComponents;
	
	if(cgl_ctx == NULL)
	return NO;
	
	/* Bind the FBO as the rendering destination */
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _frameBuffer);
	glGetIntegerv(GL_VIEWPORT, viewport);
	glViewport(0, 0, kSize, kSize);
	glGetIntegerv(GL_MATRIX_MODE, &saveMode);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrtho(0, kSize, 0, kSize, -1, 1);
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	/* Draw the texture in its native colorspace */
	if(image && [image lockTextureRepresentationWithColorSpace:[image imageColorSpace] forBounds:[image imageBounds]]) {
		[image bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
		
		glColor4f(1.0, 1.0, 1.0, 1.0);
		glBegin(GL_QUADS);
			glTexCoord2f(1.0,1.0);
			glVertex3f(kSize, kSize, 0);
			glTexCoord2f(0.0, 1.0);
			glVertex3f(0, kSize, 0);
			glTexCoord2f(0.0, 0.0);
			glVertex3f(0, 0, 0);
			glTexCoord2f(1.0, 0.0);
			glVertex3f(kSize, 0, 0);
		glEnd();
		
		[image unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE0];
		
		[image unlockTextureRepresentation];
	}
	else {
		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	
	/* Copy the rendered pixels into the VBO */
	glBindBuffer(GL_PIXEL_PACK_BUFFER_ARB, _vertexBuffer);	
	glReadPixels(0, 0, kSize, kSize, GL_RGBA, GL_FLOAT, NULL);
	glBindBuffer(GL_PIXEL_PACK_BUFFER_ARB, 0);
	
	/* Unbind the FBO and restore previous rendering destination */
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(saveMode);
	glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
	
	/* Setup OpenGL state */
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glTranslatef(-0.5, -0.5, -0.5);
	saveEnabled = glIsEnabled(GL_DEPTH_TEST);
	if(!saveEnabled)
	glEnable(GL_DEPTH_TEST);
	if(self.inputWireFrame) {
		glGetIntegerv(GL_POLYGON_MODE, saveModes);
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
	}
	colorComponents = CGColorGetComponents(self.inputColor);
	glColor4f(colorComponents[0], colorComponents[1], colorComponents[2], colorComponents[3]);
	
	/* Draw the VBO */
	glEnableClientState(GL_VERTEX_ARRAY);
	glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
	glVertexPointer(4, GL_FLOAT, 0, NULL);
	glDrawElements(GL_TRIANGLES, (kSize - 1) * (kSize - 1) * 6, GL_UNSIGNED_INT, _indices);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glDisableClientState(GL_VERTEX_ARRAY);
	
	/* Restore OpenGL state */
	if(!saveEnabled)
	glDisable(GL_DEPTH_TEST);
	if(self.inputWireFrame) {
		glPolygonMode(GL_FRONT, saveModes[0]);
		glPolygonMode(GL_BACK, saveModes[0]);
	}
	glPopMatrix();
	
	/* Check for OpenGL errors */
	if(error = glGetError())
	[context logMessage:@"OpenGL error %04X", error];
	
	return (error ? NO : YES);
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	CGLContextObj					cgl_ctx = [context CGLContextObj];
	
	if(cgl_ctx == NULL)
	return;
	
	/* Destroy OpenGL resources */
	glDeleteFramebuffersEXT(1, &_frameBuffer);
	glDeleteRenderbuffersEXT(1, &_renderBuffer);
	glDeleteBuffers(1, &_vertexBuffer);
	
	/* Destroy index buffer */
	free(_indices);
}

@end
