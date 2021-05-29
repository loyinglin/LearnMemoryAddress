//
//  main.m
//  LearnMemoryAddress
//
//  Created by loyinglin on 2021/5/20.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    NSLog(@"main_stack => 0x%lx", &appDelegateClassName);
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
