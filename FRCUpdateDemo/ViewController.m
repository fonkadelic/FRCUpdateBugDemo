//
//  ViewController.m
//  FRCUpdateDemo
//
//  Created by Vlas Voloshin on 19/07/2015.
//  Copyright © 2015 Vlas Voloshin. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "Library.h"

@interface NSIndexPath (VVShortDescription)

- (NSString *)vv_shortDescription;

@end

@implementation NSIndexPath (VVShortDescription)

- (NSString *)vv_shortDescription
{
    return [NSString stringWithFormat:@"(%ld - %ld)", (long)self.section, (long)self.row];
}

@end



@interface ViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, weak) IBOutlet UITextView *logView;
@property (nonatomic, strong) NSFetchedResultsController *resultsController;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Observe saves of all contexts
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
    
    // Make sure to initialize results controller and fault-in any existing objects (so that FRC tracks merged updates in them).
    NSArray *objects = self.resultsController.fetchedObjects;
    NSString *joinedObjects = [[objects valueForKey:@"name"] componentsJoinedByString:@", "];
    [self logMessage:[NSString stringWithFormat:@"We have %lu libraries: %@.", (unsigned long)objects.count, joinedObjects]];
}

- (IBAction)createLibrariesButtonPressed:(id)sender
{
    // Create and save some objects right on main context
    NSManagedObjectContext *context = [(AppDelegate *)[UIApplication sharedApplication].delegate managedObjectContext];
    
    // Make sure to specify names that create unambiguous order in FRC!
    Library *library1 = [NSEntityDescription insertNewObjectForEntityForName:@"Library" inManagedObjectContext:context];
    library1.name = @"Library A";
    
    Library *library2 = [NSEntityDescription insertNewObjectForEntityForName:@"Library" inManagedObjectContext:context];
    library2.name = @"Library B";

    Library *library3 = [NSEntityDescription insertNewObjectForEntityForName:@"Library" inManagedObjectContext:context];
    library3.name = @"Library C";
    
    [(AppDelegate *)[UIApplication sharedApplication].delegate saveContext];
}

- (IBAction)makeChangeButtonPressed:(id)sender
{
    // Create a temporary auxilary context and connect it to the same coordinator
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = [(AppDelegate *)[UIApplication sharedApplication].delegate persistentStoreCoordinator];
    
    // Make an change to an object, which is not related to the order of objects in FRC
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Library"];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", @"Library A"];
    Library *library = [[context executeFetchRequest:request error:NULL] firstObject];
    
    library.flag = @(NO);
    
    [self logMessage:@"Saving auxilary context..."];
    [context save:NULL];
    // !!! For some reason this causes FRC to report a move from index 0 to index 0!
}

- (IBAction)clearAllButtonPressed:(id)sender
{
    self.logView.text = @"";
    
    NSManagedObjectContext *context = [(AppDelegate *)[UIApplication sharedApplication].delegate managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Library"];
    NSArray *libraries = [context executeFetchRequest:request error:NULL];
    for (Library *library in libraries) {
        [context deleteObject:library];
    }
    
    [(AppDelegate *)[UIApplication sharedApplication].delegate saveContext];
}

- (void)logMessage:(NSString *)message
{
    NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    NSString *formattedMessage = [NSString stringWithFormat:@"\n%@: %@", dateString, message];
    self.logView.text = [self.logView.text stringByAppendingString:formattedMessage];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
}

- (NSFetchedResultsController *)resultsController
{
    if (_resultsController != nil) {
        return _resultsController;
    }
    
    // Order the objects by "name" attribute, without sections
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Library"];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES] ];
    
    NSManagedObjectContext *context = [(AppDelegate *)[UIApplication sharedApplication].delegate managedObjectContext];
    _resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
    _resultsController.delegate = self;
    
    NSError *error = nil;
    if (![_resultsController performFetch:&error]) {
        NSAssert(NO, @"Failed to fetch communities");
    }
    
    return _resultsController;
}

- (void)controllerWillChangeContent:(nonnull NSFetchedResultsController *)controller
{
    [self logMessage:@"Will change content..."];
}

- (void)controllerDidChangeContent:(nonnull NSFetchedResultsController *)controller
{
    [self logMessage:@"Did change content."];
}

- (void)controller:(nonnull NSFetchedResultsController *)controller didChangeObject:(nonnull NSManagedObject *)anObject atIndexPath:(nullable NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(nullable NSIndexPath *)newIndexPath
{
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [self logMessage:[NSString stringWithFormat:@"Inserted at %@.", newIndexPath.vv_shortDescription]];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [self logMessage:[NSString stringWithFormat:@"Deleted at %@.", indexPath.vv_shortDescription]];
            break;
        }
        case NSFetchedResultsChangeMove: {
            [self logMessage:[NSString stringWithFormat:@"Moved from %@ to %@.", indexPath.vv_shortDescription, newIndexPath.vv_shortDescription]];
            if ([newIndexPath isEqual:indexPath]) {
                [self logMessage:@"!!! New index is equal to old index - this is a bug !!!"];
            }
            break;
        }
        case NSFetchedResultsChangeUpdate: {
            [self logMessage:[NSString stringWithFormat:@"Updated at %@.", indexPath.vv_shortDescription]];
            break;
        }
    }
}

- (void)contextDidSave:(NSNotification *)notification
{
    NSManagedObjectContext *mainContext = [(AppDelegate *)[UIApplication sharedApplication].delegate managedObjectContext];
    // Merge any changes saved in an auxilary context into the main context
    if (notification.object != mainContext) {
        [self logMessage:@"Merging a save of auxilary context..."];
        [mainContext mergeChangesFromContextDidSaveNotification:notification];
    } else {
        [self logMessage:@"Saved main context."];
    }
}

@end
