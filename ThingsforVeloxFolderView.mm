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
    NSArray *_tasks;
    UIImage *_sepImage;
}

- (NSArray *)tasks;

@end

@implementation ThingsforVeloxFolderView

- (UIView *)initWithFrame:(CGRect)aFrame{
	self = [super initWithFrame:aFrame];
    if (self){
        _tasks = [[self tasks] retain];
        if (_tasks == nil) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,0,0)];
            label.font = [UIFont boldSystemFontOfSize:16.f];
            label.textColor = [UIColor whiteColor];
            label.backgroundColor = [UIColor clearColor];
            label.text = @"Hola! Nothing to do for today!";
            CGRect frame;
            frame.size = [label sizeThatFits:aFrame.size];
            frame.origin = CGPointMake(roundf((aFrame.size.width - frame.size.width) / 2), roundf((aFrame.size.height - frame.size.height) / 2));
            label.frame = frame;
            [self addSubview:label];
            [label release];
        } else {
            _sepImage = [[UIImage imageNamed:@"BulletinListCellSeparator"] retain];

            aFrame.size.height = MIN([_tasks count], 3u) * TASK_CELL_HEIGHT;
            self.frame = aFrame;
            
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
	}
    return self;
}

- (void)dealloc {
    [_tasks release];
    [_sepImage release];
    [super dealloc];
}

- (NSArray *)tasks {
    NSMutableArray *tasks = [NSMutableArray array];
    
    sqlite3 *db;
    NSString *dbPath = [[[[[[NSClassFromString(@"SBApplicationController") sharedInstance] applicationsWithBundleIdentifier:@"com.culturedcode.ThingsTouch"] lastObject] path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Documents/Things.sqlite3"];
    int err = sqlite3_open([dbPath UTF8String], &db);
    if (err) {
        NSLog(@"failed to open db, err: %d, path: %@", err, dbPath);
    } else {
        // SQL: SELECT uuid, title FROM TMTask WHERE startDate NOT NULL AND startDate < 1368082107 AND status == 0 AND type == 0 ORDER BY userModificationDate DESC;
        char sql[300];
        if (sprintf(sql, "SELECT uuid, title FROM TMTask WHERE startDate NOT NULL AND startDate < %.2f AND status == 0 AND type == 0 ORDER BY userModificationDate DESC", [[NSDate date] timeIntervalSince1970]) > 0) {
            NSLog(@"SQL: %s", sql);
            char *emsg = NULL;
            err = sqlite3_exec(db, sql, task_callback, tasks, &emsg);
            if (err != SQLITE_OK) {
                NSLog(@"SQL error: %s", emsg);
                sqlite3_free(emsg);
            }
        } else {
            NSLog(@"failed to format sql");
        }
    }
    
    sqlite3_close(db);
    
    return [tasks count] > 0 ? tasks : nil;
}

- (ThingsTask *)taskAtIndexPath:(NSIndexPath *)indexPath {
    return [_tasks objectAtIndex:(indexPath.row / 2)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_tasks count] * 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row % 2 == 0 ? 44.f : _sepImage.size.height;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row % 2 == 0 ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"things:task?uuid=%@", [[self taskAtIndexPath:indexPath] uuid]]]];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.row % 2 == 0) {
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
	return TASK_CELL_HEIGHT;
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

@end
