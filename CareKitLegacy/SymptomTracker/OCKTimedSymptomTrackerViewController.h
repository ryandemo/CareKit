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


#import <CareKitLegacy/CareKitLegacy.h>


NS_ASSUME_NONNULL_BEGIN

/**
 An enumeration of the symptom tracker times available.
 */
typedef NS_ENUM(NSInteger, OCKTimedSymptomTrackerTime) {

    OCKTimedSymptomTrackerTimeMorning = 0,
    
    OCKTimedSymptomTrackerTimeNoon,
    
    OCKTimedSymptomTrackerTimeAfternoon,
    
    OCKTimedSymptomTrackerTimeEvening
    
};

@class OCKTimedSymptomTrackerViewController;

/**
 An object that adopts the `OCKSymptomTrackerViewControllerDelegate` protocol is responsible for presenting
 the appropriate view controller to perform the assessment. It also allows the object to modify or update the
 events before they are displayed.
 */
@protocol OCKTimedSymptomTrackerViewControllerDelegate <NSObject>

@required

/**
 Tells the delegate when the user selected an assessment event.
 
 @param viewController      The view controller providing the callback.
 @param assessmentEvent     The assessment event that the user selected.
 */
- (void)timedSymptomTrackerViewController:(OCKTimedSymptomTrackerViewController *)viewController didSelectRowWithTrackerTime:(OCKTimedSymptomTrackerTime)trackerTime AndEvents:(NSArray<OCKCarePlanEvent *> *)events;

@optional

/**
 Tells the delegate when a new set of events is fetched from the care plan store.
 
 This is invoked when the date changes or when the care plan store's `carePlanStoreActivityListDidChange` delegate method is called.
 This provides a good opportunity to update the store such as fetching data from HealthKit.
 
 @param viewController      The view controller providing the callback.
 @param events              An array containing the fetched set of assessment events grouped by activity.
 @param dateComponents      The date components for which the events will be displayed.
 */
- (void)timedSymptomTrackerViewController:(OCKTimedSymptomTrackerViewController *)viewController willDisplayEvents:(NSArray<OCKCarePlanEvent*> *)events dateComponents:(NSDateComponents *)dateComponents;

/**
 Asks the delegate if the symptom tracker view controller should enable pull-to-refresh behavior on the activities list. If not implemented,
 pull-to-refresh will not be enabled.
 
 If returned YES, the `symptomTrackerViewController:didActivatePullToRefreshControl:` method should be implemented to provide custom
 refreshing behavior when triggered by the user.
 
 @param viewController              The view controller providing the callback.
 */
- (BOOL)shouldEnablePullToRefreshInTimedSymptomTrackerViewController:(OCKTimedSymptomTrackerViewController *)viewController;

/**
 Tells the delegate the user has triggered pull to refresh on the activities list.
 
 Provides the opportunity to refresh data in the local store by, for example, fetching from a cloud data store.
 This method should always be implmented in cases where `shouldEnablePullToRefreshInSymptomTrackerViewController:` might return YES.
 
 @param viewController              The view controller providing the callback.
 @param refreshControl              The refresh control which has been triggered, where `isRefreshing` should always be YES.
                                    It is the developers responsibility to call `endRefreshing` as appropriate, on the main thread.
 */
- (void)timedSymptomTrackerViewController:(OCKTimedSymptomTrackerViewController *)viewController didActivatePullToRefreshControl:(UIRefreshControl *)refreshControl;

@end


/**
 The `OCKSymptomTrackerViewController` class is a view controller that displays the activities and events
 from an `OCKCarePlanStore` that are of assessment type (see `OCKCarePlanActivityTypeAssessment`).
 
 It must be embedded inside a `UINavigationController` to allow for calendar operations, such as `Today` bar button item.
 */
OCK_CLASS_AVAILABLE
@interface OCKTimedSymptomTrackerViewController : UIViewController

- (instancetype)init NS_UNAVAILABLE;

/**
 Returns an initialized symptom tracker view controller using the specified store.
 
 @param store        A care plan store.
 
 @return An initialized symptom tracker view controller.
 */
- (instancetype)initWithCarePlanStore:(OCKCarePlanStore *)store;

/**
 *  Show today's date in the week view
 *
 *  @param sender id of the sender
 */
- (void)showToday:(id)sender;

/**
 The care plan store that provides the content for the symptom tracker.
 
 The symptom tracker displays activites and events that are of assessment type (see `OCKCarePlanActivityTypeAssessment`).
 */
@property (nonatomic, readonly) OCKCarePlanStore *store;

/**
 The delegate is used to provide the appropriate view controller for a given assessment event.
 It also allows the fetched events to be modified or updated before they are displayed.
 
 See the `OCKTimedSymptomTrackerViewControllerDelegate` protocol.
 */
@property (nonatomic, weak, nullable) id<OCKTimedSymptomTrackerViewControllerDelegate> delegate;

/**
 A reference to the `UITableView` contained in the view controller
 */
@property (nonatomic, readonly, nonnull) UITableView *tableView;

/**
 The tint color that will be used to fill the ring view.
 
 If the value is not specified, the app's tint color is used.
 */
@property (nonatomic, null_resettable) UIColor *glyphTintColor;

/**
 The string that will be used as the Symptom Tracker header title.
 
 If the value is not specified, CareKit's default string ("Activity Completion") is used.
 */
@property (nonatomic, null_resettable) NSString *headerTitle;

/**
 The glyph type for the header view (see OCKGlyphType).
 */
@property (nonatomic) OCKGlyphType glyphType;

/**
 Image name string if using a custom image. Cannot access image name once image has been created
 and we need a way to access that to send the custom image name string to the watch
 */
@property (nonatomic) NSString *customGlyphImageName;

//ADDED
@property (nonatomic) NSDateComponents *selectedDate;

@end

NS_ASSUME_NONNULL_END
