#import "VeloxFolderViewProtocol.h"
#import <SpringBoard/SpringBoard.h>
#include <sqlite3.h>

#define TASK_CELL_HEIGHT 44.f

@interface ThingsTask : NSObject
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *notes;
@end

static int task_callback(void *param, int argc, char **argv, char **column){
    NSMutableArray *tasks = (NSMutableArray *)param;
    ThingsTask *t = [[ThingsTask alloc] init];
    for (int i = 0; i < argc; i++) {
        const char *val = argv[i] ? argv[i] : "";
        if (strcmp(column[i], "title") == 0) {
            t.title = [NSString stringWithUTF8String:val];
        } else if (strcmp(column[i], "uuid") == 0) {
            t.uuid = [NSString stringWithUTF8String:val];
        } else if (strcmp(column[i], "notes") == 0) {
            t.notes = [NSString stringWithUTF8String:val];
        }
    }
    [tasks addObject:t];
    [t release];
    return 0;
}

@interface ThingsforVeloxFolderView : UIView <VeloxFolderViewProtocol, UITableViewDelegate, UITableViewDataSource> {
    NSString *_thingsAppDirectory;
    NSArray *_tasks;
    UIImage *_sepImage;
}

- (NSArray *)tasks;

@end

@implementation ThingsforVeloxFolderView

- (UIView *)initWithFrame:(CGRect)aFrame{
	self = [super initWithFrame:aFrame];
    if (self){
        _thingsAppDirectory = [[[[[[NSClassFromString(@"SBApplicationController") sharedInstance] applicationsWithBundleIdentifier:@"com.culturedcode.ThingsTouch"] lastObject] path] stringByDeletingLastPathComponent] retain];
        NSLog(@"Things app directory: %@", _thingsAppDirectory);
        _tasks = [[self tasks] retain];

        _sepImage = [[UIImage imageNamed:@"BulletinListCellSeparator"] retain];

        UITableView *table = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        table.backgroundColor = [UIColor clearColor];
        table.backgroundView = nil;
        table.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        table.separatorStyle = UITableViewCellSeparatorStyleNone;
        table.dataSource = self;
        table.delegate = self;
        [self addSubview:table];
        [table release];
	}
    return self;
}

- (void)dealloc {
    [_thingsAppDirectory release];
    [_tasks release];
    [_sepImage release];
    [super dealloc];
}

- (NSArray *)tasks {
    NSMutableArray *tasks = [NSMutableArray array];
    
    sqlite3 *db;
    NSString *dbPath = [_thingsAppDirectory stringByAppendingPathComponent:@"Documents/Things.sqlite3"];
    int err = sqlite3_open([dbPath UTF8String], &db);
    if (err) {
        NSLog(@"failed to open db, err: %d, path: %@", err, dbPath);
    } else {
        char *emsg = NULL;
        err = sqlite3_exec(db, "SELECT uuid, title FROM TMTask WHERE startDate NOT NULL AND startDate NOT NULL AND stopDate IS NULL AND trashed == 0 AND start == 1 ORDER BY userModificationDate DESC", task_callback, tasks, &emsg);
        if (err != SQLITE_OK) {
            NSLog(@"SQL error: %s", emsg);
            sqlite3_free(emsg);
        }
    }
    
    sqlite3_close(db);
    
    return [tasks count] > 0 ? tasks : nil;
}

- (ThingsTask *)taskAtIndexPath:(NSIndexPath *)indexPath {
    return [_tasks objectAtIndex:(indexPath.row / 2)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return ([_tasks count] == 0 ? 1 : [_tasks count]) * 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row % 2 == 0 ? 44.f : _sepImage.size.height;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row % 2 == 0 ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // TODO open Things app to display selected tasks.
    /*
    NSString *uuid = [[self taskAtIndexPath:indexPath] uuid];
    if (uuid == nil) {
        return ;
    }

    NSString *appStateFilePath = [_thingsAppDirectory stringByAppendingPathComponent:@"Documents/AppState.plist"];
    NSMutableDictionary *appState = [NSMutableDictionary dictionaryWithContentsOfFile:appStateFilePath];
    [[appState objectForKey:@"SourcesControllerState"] removeObjectForKey:@"SelectedPath"];
    NSMutableArray *controllers = [NSMutableArray array];
    [controllers addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        uuid, @"SelectedTask", @"TodayList", @"ListClass", [NSNumber numberWithInt:2],
        @"State", @"TasksViewController", @"Class", nil]];
    [controllers addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], @"Editing", uuid, @"Task", @"TaskDetailViewController", @"Class", nil]];
    [appState setObject:controllers forKey:@"AppStateViewControllers"];
    [appState writeToFile:appStateFilePath atomically:YES];
    */

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"things:task"]];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.row % 2 == 0) {
        if ([_tasks count] > 0) {
            static NSString *CID = @"cell";
            cell = [tableView dequeueReusableCellWithIdentifier:CID];
            if (cell == nil) {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DefaultCell"] autorelease];
                cell.backgroundColor = [UIColor clearColor];
                cell.contentView.backgroundColor = [UIColor clearColor];
                cell.imageView.image = [UIImage imageNamed:@"BulletinListUnreadAccessory"];
                cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BulletinListCellSelection"]] autorelease];
                cell.textLabel.backgroundColor = [UIColor clearColor];
                cell.textLabel.font = [UIFont boldSystemFontOfSize:16.f];
                cell.textLabel.textColor = [UIColor whiteColor];
            }
            cell.textLabel.text = [self taskAtIndexPath:indexPath].title;
        } else {
            static NSString *CID = @"emptycell";
            cell = [tableView dequeueReusableCellWithIdentifier:CID];
            if (cell == nil) {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DefaultCell"] autorelease];
                cell.backgroundColor = [UIColor clearColor];
                cell.contentView.backgroundColor = [UIColor clearColor];
                cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BulletinListCellSelection"]] autorelease];
                cell.textLabel.backgroundColor = [UIColor clearColor];
                cell.textLabel.font = [UIFont boldSystemFontOfSize:16.f];
                cell.textLabel.textColor = [UIColor whiteColor];
                cell.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
            }
            cell.textLabel.text = @"Nothing to do for today";
        }
        
    } else {
        static NSString *CID = @"sepcell";
        cell = [tableView dequeueReusableCellWithIdentifier:CID];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DefaultCell"] autorelease];
            cell.backgroundView = [[[UIImageView alloc] initWithImage:_sepImage] autorelease];
            cell.contentView.backgroundColor = [UIColor clearColor];
            cell.textLabel.backgroundColor = [UIColor clearColor];
        }
    }
    return cell;
}

- (float)realHeight {
    return self.bounds.size.height;
}

+(int)folderHeight{
	return TASK_CELL_HEIGHT * 4;
}

@end

@implementation ThingsTask

@synthesize uuid, title, notes;

- (void)dealloc{
    [uuid release];
    [title release];
    [notes release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%@", uuid, title];
}

@end
