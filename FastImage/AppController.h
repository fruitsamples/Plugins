#import <Quartz/Quartz.h>

/* Customized QCView that allows us to override the execution arguments */
@interface AppView : QCView
@end

/* The application controller */
@interface AppController : NSObject
{
    IBOutlet AppView*		qcView;
}
@end
