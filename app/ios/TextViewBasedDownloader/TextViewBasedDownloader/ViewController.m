//
//  ViewController.m
//  TextViewBasedDownloader
//
//  Created by daniel-kisoon-kwon on 2016. 9. 18..
//  Copyright © 2016년 daniel-kisoon-kwon. All rights reserved.
//

#import "ViewController.h"

static NSString *const kKeychainItemName = @"Google Drive File Downloader";
static NSString *const kClientID = @"583210179489-k8ikhr62icbvs7p1h3fkvsbp32cbk0aa.apps.googleusercontent.com";

@implementation ViewController

@synthesize service = _service;
@synthesize output = _output;

// When the view loads, create necessary subviews, and initialize the Drive API service.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create a UITextView to display output.
    self.output = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.output.editable = false;
    self.output.contentInset = UIEdgeInsetsMake(20.0, 0.0, 20.0, 0.0);
    self.output.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.output];
    
    // Initialize the Drive API service & load existing credentials from the keychain if available.
    self.service = [[GTLServiceDrive alloc] init];
    self.service.authorizer =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                          clientID:kClientID
                                                      clientSecret:nil];
}

// When the view appears, ensure that the Drive API service is authorized, and perform API calls.
- (void)viewDidAppear:(BOOL)animated {
    if (!self.service.authorizer.canAuthorize) {
        // Not yet authorized, request authorization by pushing the login UI onto the UI stack.
        [self presentViewController:[self createAuthController] animated:YES completion:nil];
    } else {
        [self fetchFiles];
        //[GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
    }
}

// Construct a query to get names and IDs of 10 files using the Google Drive API.
- (void)fetchFiles {
    self.output.text = @"Getting files...";
    GTLQueryDrive *query =
    [GTLQueryDrive queryForFilesList];
    //query.pageSize = 10;
    query.fields = @"nextPageToken, files(id, name, webContentLink, fileExtension, fullFileExtension, originalFilename, parents, size, mimeType, trashed)";
    [self.service executeQuery:query
                      delegate:self
             didFinishSelector:@selector(displayResultWithTicket:finishedWithObject:error:)];
}

- (NSString*)getTargetFolderIDFromFileList:(NSArray*)files target:(NSString*)target {
    NSString* ret = nil;
    for (GTLDriveFile *file in files) {
        if ( [[file.name lowercaseString] isEqual:[target lowercaseString]] &&
            [file.mimeType isEqual:@"application/vnd.google-apps.folder"] &&
            file.trashed ) {
            ret = file.identifier;
            break;
        }
    }
    return ret;
}

- (NSMutableArray*)getTargetDownloadFileList:(NSArray*)files target:(NSString*)target {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSString* targetFolderID = [self getTargetFolderIDFromFileList:files target:target];
    
    for (GTLDriveFile *file in files) {
        if ( [ [file.fileExtension lowercaseString] isEqual:@"nxb"] &&
            ![file.mimeType isEqual:@"application/vnd.google-apps.folder"] &&
            file.trashed &&
            [targetFolderID isEqualToString:(NSString*)file.parents[0]] ) {
            [array addObject:file];
            NSLog(@"Target file list: %@", file.name);
        }
    }
    
    return array;
}

- (BOOL)shouldDownloadFilesInFileList:(NSArray*)targetDownloadFileList error:(NSError *)error{
    BOOL ret = YES;
    if ( [self getTargetFolderIDFromFileList:targetDownloadFileList target:@"NxbFiles"] == nil ) {
        ret = NO;
        self.output.text = @"NxbFolder does not exist!";
        [self showAlert:@"Error" message:@"NxbFolder does not exist!"];
    }
    if ( error ) {
        ret = NO;
        self.output.text = error.localizedDescription;
        [self showAlert:@"Error" message:error.localizedDescription];
    }
    if ( targetDownloadFileList.count <= 0 ) {
        ret = NO;
        self.output.text = @"No files found.";
        [self showAlert:@"Error" message:error.localizedDescription];
    }
    return ret;
}

- (void)downloadFilesInFileList:(NSMutableArray*)files {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSMutableString *textViewString = [[NSMutableString alloc] init];
    NSLog(@"my path:%@",documentsDirectory);
    
    self.output.text = @"Download Files..";
    [textViewString appendString:@"[Done] Downloaded Files\n\n"];
    for (GTLDriveFile *file in files) {
        [textViewString appendFormat:@"%@ (%@ byte)\n", file.name, file.size];
        [[self.service.fetcherService fetcherWithURLString:file.webContentLink] beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
            if ( error ) {
                NSLog(@"An error occurred: %@", error);
            } else {
                NSLog(@"Downloading %@ - %@", file.name, [data writeToFile:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",file.name]] atomically:YES] ? @"OK" : @"FAILED");
                if ( file == files[files.count-1] ) {
                    [self showAlert:@"DONE" message:@"Download success!"];
                    self.output.text = textViewString;
                }
            }
        }];
    }
}

// Process the response and display output.
- (void)displayResultWithTicket:(GTLServiceTicket *)ticket
             finishedWithObject:(GTLDriveFileList *)response
                          error:(NSError *)error {
    if ( [self shouldDownloadFilesInFileList:response.files error:error] ) {
        [self downloadFilesInFileList: [self getTargetDownloadFileList:response.files target:@"NxbFiles"] ];
    }
}


// Creates the auth controller for authorizing access to Drive API.
- (GTMOAuth2ViewControllerTouch *)createAuthController {
    GTMOAuth2ViewControllerTouch *authController;
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    NSArray *scopes = [NSArray arrayWithObjects:kGTLAuthScopeDrive, nil];
    authController = [[GTMOAuth2ViewControllerTouch alloc]
                      initWithScope:[scopes componentsJoinedByString:@" "]
                      clientID:kClientID
                      clientSecret:nil
                      keychainItemName:kKeychainItemName
                      delegate:self
                      finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

// Handle completion of the authorization process, and update the Drive API
// with the new credentials.
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)authResult
                 error:(NSError *)error {
    if (error != nil) {
        [self showAlert:@"Authentication Error" message:error.localizedDescription];
        self.service.authorizer = nil;
    }
    else {
        self.service.authorizer = authResult;
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// Helper for showing an alert
- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:title
                                        message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok =
    [UIAlertAction actionWithTitle:@"OK"
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction * action)
     {
         [alert dismissViewControllerAnimated:YES completion:nil];
     }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
    
}

@end
