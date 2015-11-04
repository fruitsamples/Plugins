#import <Quartz/Quartz.h>

#import "FreeFrame.h"

/* Internal structure to hold FreeFrame plug-in info */
typedef struct
{
	pthread_mutex_t				mutex; //Needed to ensure use from a single thread at once
	FF_Main_FuncPtr				functionPtr;
	unsigned int				uniqueID;
	NSString*					name;
	NSString*					description;
	NSString*					copyright;
	BOOL						isSource,
								supportsFrameCopy;
	
	unsigned					count;
} PlugInInfo;

@interface FreeFrameHostPlugIn : QCPlugIn
{
	unsigned int				_plugInID;
	
	PlugInInfo*					_info;
	NSMutableArray*				_parameterPorts;
	unsigned int				_instanceIdentifier;
	VideoInfoStruct				_instanceInfo;
}

/* Declare an internal setting as a property of type unsigned int */
@property unsigned int plugInID;

/* Declare a property output port of type "Image" and with the key "outputImage" */
@property(assign) id<QCPlugInOutputImageProvider> outputImage;

@end

@interface FreeFrameHostViewController : QCPlugInViewController
{
	NSPopUpButton*				plugInMenu;
}
- (IBAction) selectPlugIn:(id)sender;
@end
