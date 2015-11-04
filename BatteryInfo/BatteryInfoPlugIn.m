/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#import "BatteryInfoPlugIn.h"

#define	kQCPlugIn_Name				@"Battery Info"
#define	kQCPlugIn_Description		@"This patch returns information about the primary battery."

@implementation BatteryInfoPlugIn

/* We need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation */
@dynamic outputInstalled, outputConnected, outputCharging, outputCurrent, outputVoltage, outputCapacity, outputMaxCapacity;

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"outputInstalled"])
	return [NSDictionary dictionaryWithObject:@"Installed" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputCharging"])
	return [NSDictionary dictionaryWithObject:@"Charging" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputConnected"])
	return [NSDictionary dictionaryWithObject:@"Power Connected" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputCurrent"])
	return [NSDictionary dictionaryWithObject:@"Current (mA)" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputVoltage"])
	return [NSDictionary dictionaryWithObject:@"Voltage (mV)" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputCapacity"])
	return [NSDictionary dictionaryWithObject:@"Capacity" forKey:QCPortAttributeNameKey];
	if([key isEqualToString:@"outputMaxCapacity"])
	return [NSDictionary dictionaryWithObject:@"Maximum Capacity" forKey:QCPortAttributeNameKey];
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a provider (it provides data from an external source) */
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) but we need idling */
	return kQCPlugInTimeModeIdle;
}

@end

@implementation BatteryInfoPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/* Setup */
	
	return YES;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CFTypeRef				info;
	CFArrayRef				list;
	CFDictionaryRef			battery;
	
	info = IOPSCopyPowerSourcesInfo();
	if(info == NULL)
	return NO;
	list = IOPSCopyPowerSourcesList(info);
	if(list == NULL) {
		CFRelease(info);
		return NO;
	}
	
	if(CFArrayGetCount(list) && (battery = IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(list, 0)))) {
		self.outputInstalled = [[(NSDictionary*)battery objectForKey:@kIOPSIsPresentKey] boolValue];
		self.outputConnected = [(NSString*)[(NSDictionary*)battery objectForKey:@kIOPSPowerSourceStateKey] isEqualToString:@kIOPSACPowerValue];
		self.outputCharging = [[(NSDictionary*)battery objectForKey:@kIOPSIsChargingKey] boolValue];
		self.outputCurrent = [[(NSDictionary*)battery objectForKey:@kIOPSCurrentKey] doubleValue];
		self.outputVoltage = [[(NSDictionary*)battery objectForKey:@kIOPSVoltageKey] doubleValue];
		self.outputCapacity = [[(NSDictionary*)battery objectForKey:@kIOPSCurrentCapacityKey] doubleValue];
		self.outputMaxCapacity = [[(NSDictionary*)battery objectForKey:@kIOPSMaxCapacityKey] doubleValue];
	}
	else {
		self.outputInstalled = NO;
		self.outputConnected = NO;
		self.outputCharging = NO;
		self.outputCurrent = 0.0;
		self.outputVoltage = 0.0;
		self.outputCapacity = 0.0;
		self.outputMaxCapacity = 0.0;
	}
	
	CFRelease(list);
	CFRelease(info);
	
	return YES;
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/* Clean up*/
}

@end
