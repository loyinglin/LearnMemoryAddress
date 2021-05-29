//
//  ViewController.m
//  LearnMemoryAddress
//
//  Created by loyinglin on 2021/5/20.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>
#include <os/log.h>
#import <mach-o/dyld.h>

// mmap
#import <sys/mman.h>
#import <sys/stat.h>


static int vcStaticInt = 12;
static int vcStaticNotInit;
static const char vcStaticInitStr[10] = "hello";
static char vcStaticNotInitStr[10];

struct TestStructObject {
    char name[1024*100];
    int value;
};
typedef struct TestStructObject TestStructObject;

class TestCPPObject {
public:
    char name[8];
    int value;
};

class TestCPPBigObject {
public:
    char name[1024*100];
    int value;
};

@interface TestOCObject : NSObject

@property (nonatomic, assign) TestStructObject struct_object;

@end

@implementation TestOCObject


@end

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    [self printAddress];
//    [self testStackSize:0];
//    [self testHeapSize:0];
//    [self testMalloc];
//    [self testMemoryAllocFunc];
    [self testMmap];
}



/*
 
 */
- (void)printAddress {
    intptr_t load_address = _dyld_get_image_vmaddr_slide(0);
    NSLog(@"image_load_address: 0x%016lx\n", load_address);
    
    
    NSLog(@"0x%016lx => data 0x%016lx => bss", (long)&vcStaticInt, (long)&vcStaticNotInit);
    
    char stack_address;
    UIView *heap_view_address = [[UIView alloc] init];
    NSLog(@"0x%016lx => stack 0x%016lx => heap", (long)&stack_address, (long)heap_view_address);
    
    static char func_static_not_init_str[10];
    static char func_static_init_str[10] = "test";
    NSLog(@"0x%016lx => func_static_not_init_str 0x%016lx => func_static_init_str", (long)func_static_not_init_str, (long)func_static_init_str);
    
    
    NSLog(@"0x%016lx => vcStaticInitStr 0x%016lx => vcStaticNotInitStr", (long)vcStaticInitStr, (long)vcStaticNotInitStr);
    
//    NSArray *abc = [NSArray new];
//    [(NSMutableArray *)abc addObject:@(2)];
}

/**
 关注两次运行的stackSize
 0x16ce86868
- 0x16ce86408
=0x000000460
 转换成二进制4*(16^2)+6*16=1024+96
 其中1024是申请的char数组，96是函数运行的其他临时变量。
 
 */
- (void)testStackSize:(int)count {
    char stackSize[1024];
    NSLog(@"%05d stack_address => 0x%lx ", count, (long)&stackSize);
    if (count < 1000) {
        ++count;
        [self testStackSize:count];
    }
    else {
        NSLog(@"end");
    }
}

/**
 关注stack地址和heap地址的变化
 注意stack的空间会有预留大概1MB左右
 最终运行到14000次左右崩溃，iPhone XS Max
 一次是100KB，14000次大概是1367MB左右的内存大小。
 
 */
- (void)testHeapSize:(int)count {
    char stackSize;
    TestOCObject *obj = [[TestOCObject alloc] init];
    char *head_end_address = (char *)sbrk((ptrdiff_t)0);
    NSLog(@"%05d stack_address => 0x%lx heap_address => 0x%lx head_end_address:0x%p", count, (long)&stackSize, (long)obj, head_end_address);
    if (count < 20000) {
        ++count;
        [self testHeapSize:count];
    }
    else {
        NSLog(@"end");
    }
}

/*
 通过malloc分配的内存，可以超过14000次，达到63000次左右；
 大概是通过OCalloc方法的4倍，总共有4G多的空间。
 
 */
- (void)testMalloc {
    int count = 0;
    while (true) {
        char stackSize;
        TestStructObject *obj = (TestStructObject *)malloc(sizeof(TestStructObject));
        ++count;
        
        if (obj) {
            NSLog(@"%05d stack_address => 0x%lx heap_address => 0x%lx", count, (long)&stackSize, (long)obj);
        }
        else {
            break;
        }
    }
}

/*
 
 注意各自搭配的头文件
 
 class_getInstanceSize  和  malloc_size 是不一样的
 
  各个地址是不一样的，注意OC的alloc也是不一样的
 
 */

- (void)testMemoryAllocFunc {
    TestStructObject stack_object;
    TestStructObject *heap_malloc_object = (struct TestStructObject *)malloc(sizeof(TestStructObject));
    TestCPPObject *heap_new_object = new TestCPPObject();
    TestCPPBigObject *heap_new_big_object = new TestCPPBigObject();
    
    NSLog(@"stack_address => 0x%lx heap_malloc_address => 0x%lx", (long)&stack_object, (long)heap_malloc_object);
    NSLog(@"heap_new_address => 0x%lx heap_new_big_address => 0x%lx", (long)heap_new_object, (long)heap_new_big_object);
    
    NSObject *oc_object = [[NSObject alloc] init];
    TestOCObject *oc_big_object = [[TestOCObject alloc] init];
    NSLog(@"oc_object_address => 0x%lx oc_big_object_address => 0x%lx", (long)oc_object, (long)oc_big_object);
    NSLog(@"object_size NSObject:%ld, TestOCObject:%ld", (long)class_getInstanceSize([NSObject class]), (long)class_getInstanceSize([TestOCObject class]));
    NSLog(@"real_object_size NSObject:%ld, TestOCObject:%ld", (long)malloc_size((__bridge const void *)oc_object), (long)malloc_size((__bridge const void *)oc_big_object));
}

int MapFile(const char * inPathName, void ** outDataPtr, size_t * outDataLength) {
    int outError = 0, fileDescriptor = 0;
    struct stat statInfo;
    
    // init
    *outDataPtr = NULL;
    *outDataLength = 0;
    
    do {
        // Open the file.
        fileDescriptor = open(inPathName, O_RDONLY, 0);
        
        if( fileDescriptor < 0 ) {
            outError = errno;
            break;
        }
        
        if(fstat(fileDescriptor, &statInfo)) {
            outError = errno;
            break;
        }
        
        *outDataPtr = mmap(NULL,
                           statInfo.st_size,
                           PROT_READ,
                           MAP_FILE|MAP_SHARED,
                           fileDescriptor,
                           0);
        if(*outDataPtr == MAP_FAILED) {
            outError = errno;
            break;
        }
        // length
        *outDataLength = statInfo.st_size;
        close(fileDescriptor);
    } while (false);
    
    return outError;
}

- (void)testMmap {
    NSString *imagePathStr = [[NSBundle mainBundle] pathForResource:@"abc" ofType:@"png"];
    NSString *plistPathStr = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
    NSError *error;
    
//    NSData *plistData = [NSData dataWithContentsOfFile:plistPathStr options:NSDataReadingUncached error:&error];
//    NSLog(@"plistData:0x%lx, bytes_address:0x%lx, size:%d, error:%@", (long)plistData, (long)plistData.bytes, plistData.length, error);
//    
//    NSData *normalData = [NSData dataWithContentsOfFile:imagePathStr options:NSDataReadingUncached error:&error];
//    NSLog(@"normalData:0x%lx, bytes_address:0x%lx, size:%d, error:%@", (long)normalData, (long)normalData.bytes, normalData.length, error);
    
    size_t dataLength;
    void *dataPtr;
    int errorCode = MapFile([imagePathStr cStringUsingEncoding:NSUTF8StringEncoding], &dataPtr, &dataLength);
    NSLog(@"mmapData:0x%lx, bytes_address:0x%lx, size:%d, error:%d", (long)dataPtr, (long)dataPtr, (long)dataLength, errorCode);
}


@end