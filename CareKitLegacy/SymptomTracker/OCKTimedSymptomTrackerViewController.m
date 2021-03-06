/*
 Copyright (c) 2017, Apple Inc. All rights reserved.
 Copyright (c) 2017, Erik Hornberger. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "OCKSymptomTrackerViewController.h"
#import "OCKWeekViewController.h"
#import "OCKTimedSymptomTrackerTableViewCellViewModel.h"
#import "NSDateComponents+CarePlanInternal.h"
#import "OCKWeekView.h"
#import "OCKHeaderView.h"
#import "OCKTimedSymptomTrackerTableViewCell.h"
#import "OCKWeekLabelsView.h"
#import "OCKCarePlanStore_Internal.h"
#import "OCKHelpers.h"
#import "OCKDefines_Private.h"
#import "OCKGlyph_Internal.h"


@interface OCKTimedSymptomTrackerViewController() <OCKWeekViewDelegate, OCKCarePlanStoreDelegate, UITableViewDelegate, UITableViewDataSource, UIPageViewControllerDelegate, UIPageViewControllerDataSource>

@end


@implementation OCKTimedSymptomTrackerViewController {
    UITableView *_tableView;
    UIRefreshControl *_refreshControl;
    NSMutableArray<OCKCarePlanEvent *> *_events;
    NSMutableArray *_weekValues;
    OCKHeaderView *_headerView;
    UIPageViewController *_pageViewController;
    OCKWeekViewController *_weekViewController;
    NSCalendar *_calendar;
    NSMutableArray *_constraints;
    NSMutableArray *_sectionTitles;
    NSArray<OCKTimedSymptomTrackerTableViewCellViewModel *> *_tableViewData;
    NSString *_otherString;
    NSString *_optionalString;
}

- (instancetype)init {
    OCKThrowMethodUnavailableException();
    return nil;
}

- (instancetype)initWithCarePlanStore:(OCKCarePlanStore *)store {
    self = [super init];
    if (self) {
        _store = store;
        _calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        _glyphType = OCKGlyphTypeStethoscope;
        _glyphTintColor = nil;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    self.store.symptomTrackerUIDelegate = self;
    
    [self setGlyphTintColor: _glyphTintColor];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:OCKLocalizedString(@"TODAY_BUTTON_TITLE", nil)
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(showToday:)];
    self.navigationItem.rightBarButtonItem.tintColor = self.glyphTintColor;
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
    
    [self prepareView];
    
    self.selectedDate = [NSDateComponents ock_componentsWithDate:[NSDate date] calendar:_calendar];
    
    _tableView.estimatedRowHeight = 90.0;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.tableFooterView = [UIView new];
    _tableView.estimatedSectionHeaderHeight = 0;
    _tableView.estimatedSectionFooterHeight = 0;
    
    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.tintColor = [UIColor grayColor];
    [_refreshControl addTarget:self action:@selector(didActivatePullToRefreshControl:) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;
    [self updatePullToRefreshControl];
    
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setBarTintColor:[UIColor colorWithRed:245.0/255.0 green:244.0/255.0 blue:246.0/255.0 alpha:1.0]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSAssert(self.navigationController, @"OCKSymptomTrackerViewController must be embedded in a navigation controller.");
    
    _weekViewController.weekView.delegate = self;
}

- (void)showToday:(id)sender {
    self.selectedDate = [NSDateComponents ock_componentsWithDate:[NSDate date] calendar:_calendar];
    if (_tableViewData.count > 0) {
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:NSNotFound inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (void)didActivatePullToRefreshControl:(UIRefreshControl *)sender
{
    if (nil == self.delegate ||
        ![self.delegate respondsToSelector:@selector(symptomTrackerViewController:didActivatePullToRefreshControl:)]) {
        
        return;
    }
    
    [self.delegate timedSymptomTrackerViewController:self didActivatePullToRefreshControl:sender];
}

- (void)prepareView {
    if (!_headerView) {
        _headerView = [[OCKHeaderView alloc] initWithFrame:CGRectZero];
        [self.view addSubview:_headerView];
        
    }
    _headerView.tintColor = self.glyphTintColor;
    if (self.glyphType == OCKGlyphTypeCustom) {
        UIImage *glyphImage = [self createCustomImageName:self.customGlyphImageName];
        _headerView.glyphImage = glyphImage;
    }
    if ([_headerTitle length] > 0) {
        _headerView.title = _headerTitle;
    }
    _headerView.isCareCard = NO;
    _headerView.glyphType = self.glyphType;
 
    if (!_pageViewController) {
        _pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                              navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                            options:nil];
        _pageViewController.dataSource = self;
        _pageViewController.delegate = self;
        
        if (!UIAccessibilityIsReduceTransparencyEnabled()) {
            _pageViewController.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
            
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent];
            UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurEffectView.frame = _pageViewController.view.bounds;
            blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_pageViewController.view insertSubview:blurEffectView atIndex:_pageViewController.view.subviews.count-1];
        }
        else {
            _pageViewController.view.backgroundColor = [UIColor whiteColor];
        }
        
        OCKWeekViewController *weekController = [OCKWeekViewController new];
        weekController.weekView.delegate = _weekViewController.weekView.delegate;
        weekController.weekView.ringTintColor = self.glyphTintColor;
        weekController.weekView.isCareCard = NO;
        weekController.weekView.glyphType = self.glyphType;
        _weekViewController = weekController;
        
        [_pageViewController setViewControllers:@[weekController] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
        [self.view addSubview:_pageViewController.view];
    }
    
    _tableView.showsVerticalScrollIndicator = NO;
    
    [self setUpConstraints];
}

- (void)setUpConstraints {
    [NSLayoutConstraint deactivateConstraints:_constraints];
    
    _constraints = [NSMutableArray new];
    
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _pageViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [_constraints addObjectsFromArray:@[
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.topLayoutGuide
                                                                     attribute:NSLayoutAttributeBottom
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeBottom
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:_headerView
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0
                                                                      constant:10.0],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeLeading
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeLeading
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeTrailing
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeTrailing
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:65.0],
                                        [NSLayoutConstraint constraintWithItem:_headerView
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:140.0],
                                        [NSLayoutConstraint constraintWithItem:_headerView
                                                                     attribute:NSLayoutAttributeBottom
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:_tableView
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeBottom
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeBottom
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeLeading
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeLeading
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeTrailing
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeTrailing
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_headerView
                                                                     attribute:NSLayoutAttributeLeading
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeLeading
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_headerView
                                                                     attribute:NSLayoutAttributeTrailing
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeTrailing
                                                                    multiplier:1.0
                                                                      constant:0.0]
                                        ]];
    
    [NSLayoutConstraint activateConstraints:_constraints];
}

- (void)setSelectedDate:(NSDateComponents *)selectedDate {
    NSDateComponents *today = [self today];
    _selectedDate = [selectedDate isLaterThan:today] ? today : selectedDate;
    
    _weekViewController.weekView.isToday = [[self today] isEqualToDate:selectedDate];
    _weekViewController.weekView.selectedIndex = self.selectedDate.weekday - 1;
    
    [self fetchEvents];
}

- (void)setGlyphTintColor:(UIColor *)glyphTintColor {
    _glyphTintColor = glyphTintColor;
    if (!_glyphTintColor) {
        _glyphTintColor = [OCKGlyph defaultColorForGlyph:self.glyphType];
    }
    
    _weekViewController.weekView.tintColor = _glyphTintColor;
    _headerView.tintColor = _glyphTintColor;
    self.navigationItem.rightBarButtonItem.tintColor = _glyphTintColor;
}

- (void)setHeaderTitle:(NSString *)headerTitle {
    _headerTitle = headerTitle;
    if ([_headerTitle length] > 0) {
        _headerView.title = _headerTitle;
    }
}

- (void)setDelegate:(id<OCKTimedSymptomTrackerViewControllerDelegate>)delegate
{
    _delegate = delegate;
    
    if ([NSOperationQueue currentQueue] != [NSOperationQueue mainQueue]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updatePullToRefreshControl];
        });
    } else {
        [self updatePullToRefreshControl];
    }
}

#pragma mark - Helpers

- (void)fetchEvents {
    [self.store eventsOnDate:self.selectedDate
                        type:OCKCarePlanActivityTypeAssessment
                  completion:^(NSArray<NSArray<OCKCarePlanEvent *> *> *eventsGroupedByActivity, NSError *error) {
                      NSAssert(!error, error.localizedDescription);
                      dispatch_async(dispatch_get_main_queue(), ^{
                          _events = [NSMutableArray new];
                          for (NSArray<OCKCarePlanEvent *> *events in eventsGroupedByActivity) {
                              [_events addObjectsFromArray:events];
                          }
                          
                          if (self.delegate &&
                              [self.delegate respondsToSelector:@selector(timedSymptomTrackerViewController:willDisplayEvents:dateComponents:)]) {
                              [self.delegate timedSymptomTrackerViewController:self willDisplayEvents:[_events copy] dateComponents:_selectedDate];
                          }
                          
                          [self createViewModelsForEvents:_events];
                          
                          [self updateHeaderView];
                          [self updateWeekView];
                          [_tableView reloadData];
                      });
                  }];
}

- (void)createViewModelsForEvents:(NSArray<OCKCarePlanEvent *> *)events {
    NSMutableArray *morning = [NSMutableArray new];
    NSMutableArray *noon = [NSMutableArray new];
    NSMutableArray *afternoon = [NSMutableArray new];
    NSMutableArray *evening = [NSMutableArray new];
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"hh:mm a"];
    NSDate *eventDate;
    
    for (OCKCarePlanEvent *event in events) {
        eventDate = [dateFormat dateFromString:event.activity.text];
        NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:eventDate];
        if (hour < 12) {
            [morning addObject:event];
        } else if (hour == 12) {
            [noon addObject:event];
        } else if (hour > 12 && hour < 17) {
            [afternoon addObject:event];
        } else {
            [evening addObject:event];
        }
    }
    
    OCKTimedSymptomTrackerTableViewCellViewModel *morningViewModel = [[OCKTimedSymptomTrackerTableViewCellViewModel alloc] initWithTime:OCKTimedSymptomTrackerTimeMorning andEvents:morning onSelectedDate:_selectedDate];
    OCKTimedSymptomTrackerTableViewCellViewModel *noonViewModel = [[OCKTimedSymptomTrackerTableViewCellViewModel alloc] initWithTime:OCKTimedSymptomTrackerTimeNoon andEvents:noon onSelectedDate:_selectedDate];
    OCKTimedSymptomTrackerTableViewCellViewModel *afternoonViewModel = [[OCKTimedSymptomTrackerTableViewCellViewModel alloc] initWithTime:OCKTimedSymptomTrackerTimeAfternoon andEvents:afternoon onSelectedDate:_selectedDate];
    OCKTimedSymptomTrackerTableViewCellViewModel *eveningViewModel = [[OCKTimedSymptomTrackerTableViewCellViewModel alloc] initWithTime:OCKTimedSymptomTrackerTimeEvening andEvents:evening onSelectedDate:_selectedDate];
    
    _tableViewData = [[NSArray alloc] initWithObjects:morningViewModel, noonViewModel, afternoonViewModel, eveningViewModel, nil];
}

- (void)updateHeaderView {
    _headerView.date = [NSDateFormatter localizedStringFromDate:[_calendar dateFromComponents:self.selectedDate]
                                                      dateStyle:NSDateFormatterLongStyle
                                                      timeStyle:NSDateFormatterNoStyle];
    
    NSMutableArray *values = [NSMutableArray new];
    
    [self.store dailyCompletionStatusWithType:OCKCarePlanActivityTypeAssessment
                                    startDate:self.selectedDate
                                      endDate:self.selectedDate
                                      handler:^(NSDateComponents *date, NSUInteger completedEvents, NSUInteger totalEvents) {
                                          if (totalEvents == 0) {
                                              [values addObject:@(1)];
                                          } else {
                                              [values addObject:@((float)completedEvents/totalEvents)];
                                          }
                                      } completion:^(BOOL completed, NSError *error) {
                                          NSAssert(!error, error.localizedDescription);
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              NSInteger selectedIndex = _weekViewController.weekView.selectedIndex;
                                              [_weekValues replaceObjectAtIndex:selectedIndex withObject:values.firstObject];
                                              _weekViewController.weekView.values = _weekValues;
                                              
                                              _headerView.value = [values.firstObject doubleValue];
                                          });
                                      }];
}

- (void)updatePullToRefreshControl
{
    if (nil != self.delegate &&
        [self.delegate respondsToSelector:@selector(shouldEnablePullToRefreshInSymptomTrackerViewController:)] &&
        [self.delegate shouldEnablePullToRefreshInTimedSymptomTrackerViewController:self]) {
        
        _tableView.refreshControl = _refreshControl;
    } else {
        [_tableView.refreshControl endRefreshing];
        _tableView.refreshControl = nil;
    }
}

- (UIImage *)createCustomImageName:(NSString*)customImageName {
    UIImage *customImageToReturn;
    if (customImageName != nil) {
        NSBundle *bundle = [NSBundle mainBundle];
        customImageToReturn = [UIImage imageNamed: customImageName inBundle:bundle compatibleWithTraitCollection:nil];
    } else {
        OCKGlyphType defaultGlyph = OCKGlyphTypeStethoscope;
        customImageToReturn = [[OCKGlyph glyphImageForType:defaultGlyph] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    
    return customImageToReturn;
}

- (void)updateWeekView {
    NSDate *selectedDate = [_calendar dateFromComponents:self.selectedDate];
    NSDate *startOfWeek;
    NSTimeInterval interval;
    [_calendar rangeOfUnit:NSCalendarUnitWeekOfMonth
                 startDate:&startOfWeek
                  interval:&interval
                   forDate:selectedDate];
    NSDate *endOfWeek = [startOfWeek dateByAddingTimeInterval:interval-1];
    
    NSMutableArray *values = [NSMutableArray new];
    
    [self.store dailyCompletionStatusWithType:OCKCarePlanActivityTypeAssessment
                                    startDate:[NSDateComponents ock_componentsWithDate:startOfWeek calendar:_calendar]
                                      endDate:[NSDateComponents ock_componentsWithDate:endOfWeek calendar:_calendar]
                                      handler:^(NSDateComponents *date, NSUInteger completedEvents, NSUInteger totalEvents) {
                                          if ([date isLaterThan:[self today]]) {
                                              [values addObject:@(0)];
                                          } else if (totalEvents == 0) {
                                              [values addObject:@(1)];
                                          } else {
                                              [values addObject:@((float)completedEvents/totalEvents)];
                                          }
                                      } completion:^(BOOL completed, NSError *error) {
                                          NSAssert(!error, error.localizedDescription);
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              _weekViewController.weekView.values = values;
                                              _weekValues = [values mutableCopy];
                                          });
                                      }];
}

- (NSDateComponents *)dateFromSelectedIndex:(NSInteger)index {
    NSDateComponents *newComponents = [NSDateComponents new];
    newComponents.year = _selectedDate.year;
    newComponents.month = _selectedDate.month;
    newComponents.weekOfMonth = _selectedDate.weekOfMonth;
    newComponents.weekday = index + 1;
    
    NSDate *newDate = [_calendar dateFromComponents:newComponents];
    return [NSDateComponents ock_componentsWithDate:newDate calendar:_calendar];
}

- (NSDateComponents *)today {
    return [NSDateComponents ock_componentsWithDate:[NSDate date] calendar:_calendar];
}


#pragma mark - OCKWeekViewDelegate

- (void)weekViewSelectionDidChange:(UIView *)weekView {
    OCKWeekView *currentWeekView = (OCKWeekView *)weekView;
    NSDateComponents *selectedDate = [self dateFromSelectedIndex:currentWeekView.selectedIndex];
    self.selectedDate = selectedDate;
}

- (BOOL)weekViewCanSelectDayAtIndex:(NSUInteger)index {
    NSDateComponents *today = [self today];
    NSDateComponents *selectedDate = [self dateFromSelectedIndex:index];
    return ![selectedDate isLaterThan:today];
}


#pragma mark - OCKCarePlanStoreDelegate

- (void)carePlanStore:(OCKCarePlanStore *)store didReceiveUpdateOfEvent:(OCKCarePlanEvent *)event {
    for (int i = 0; i < _events.count; i++) {
        if ([_events[i].activity.identifier isEqualToString:event.activity.identifier]) {
            _events[i] = event;
            
            if (self.delegate &&
                [self.delegate respondsToSelector:@selector(timedSymptomTrackerViewController:willDisplayEvents:dateComponents:)]) {
                [self.delegate timedSymptomTrackerViewController:self willDisplayEvents:[_events copy] dateComponents:_selectedDate];
            }
            
            [self updateHeaderView];
            [self createViewModelsForEvents:_events];
            
            [_tableView reloadData];
        }
    }
    
    if ([event.date isInSameWeekAsDate: self.selectedDate]) {
        [self updateWeekView];
    }
}

- (void)carePlanStoreActivityListDidChange:(OCKCarePlanStore *)store {
    [self fetchEvents];
}


#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
    if (completed) {
        OCKWeekViewController *controller = (OCKWeekViewController *)pageViewController.viewControllers.firstObject;
        controller.weekView.delegate = _weekViewController.weekView.delegate;
        
        NSDateComponents *components = [NSDateComponents new];
        components.day = (controller.weekIndex > _weekViewController.weekIndex) ? 7 : -7;
        NSDate *newDate = [_calendar dateByAddingComponents:components toDate:[_calendar dateFromComponents:self.selectedDate] options:0];
        
        _weekViewController = controller;
        self.selectedDate = [NSDateComponents ock_componentsWithDate:newDate calendar:_calendar];
    }
}


#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    OCKWeekViewController *controller = [OCKWeekViewController new];
    controller.weekIndex = ((OCKWeekViewController *)viewController).weekIndex - 1;
    controller.weekView.tintColor = self.glyphTintColor;
    controller.weekView.isCareCard = NO;
    controller.weekView.glyphType = self.glyphType;
    return controller;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    OCKWeekViewController *controller = [OCKWeekViewController new];
    controller.weekIndex = ((OCKWeekViewController *)viewController).weekIndex + 1;
    controller.weekView.tintColor = self.glyphTintColor;
    controller.weekView.isCareCard = NO;
    controller.weekView.glyphType = self.glyphType;
    return (![self.selectedDate isInSameWeekAsDate:[self today]]) ? controller : nil;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OCKTimedSymptomTrackerTableViewCellViewModel *viewModel = _tableViewData[indexPath.row];

    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(timedSymptomTrackerViewController:didSelectRowWithTrackerTime:AndEvents:)]) {
        [self.delegate timedSymptomTrackerViewController:self didSelectRowWithTrackerTime:viewModel.time AndEvents:viewModel.events];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _tableViewData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SymptomTrackerCell";
    OCKTimedSymptomTrackerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[OCKTimedSymptomTrackerTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:CellIdentifier];
    }
    
    [cell setUpCellWith:_tableViewData[indexPath.row]];
    return cell;
}

@end
