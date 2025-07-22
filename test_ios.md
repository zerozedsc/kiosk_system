## TEST IN IPHONE
- IPHONE 12 PRO
- IOS 18

### __GENERAL ERROR__
Another exception was thrown: The PrimaryScrollController is attached to more than one ScrollPosition.
Another exception was thrown: The PrimaryScrollController is attached to more than one ScrollPosition.
Another exception was thrown: The PrimaryScrollController is attached to more than one ScrollPosition.

main_word.password_required

### [API]
ApiException: API is not reachable. Please check your network connection. (Status Code: 0)
stackTrace:
#0      KioskApiService.checkApiHealth (package:kiosk_system/services/server/kiosk_server.dart:87:7)
<asynchronous suspension>
#1      KioskApiService.registerKioskWithPassword (package:kiosk_system/services/server/kiosk_server.dart:564:5)
<asynchronous suspension>
#2      KioskAuthService.registerKiosk (package:kiosk_system/services/auth/auth_service.dart:141:28)
<asynchronous suspension>
#3      _SignupPageState.build.<anonymous closure> (package:kiosk_system/pages/auth_page.dart:231:33)
<asynchronous suspension>

### [login page / auth service]
- error notification 
    Please enter both kiosk ID and Password -> need to use localization

### [more page / employee account]
══╡ EXCEPTION CAUGHT BY SCHEDULER LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during a scheduler callback:
The PrimaryScrollController is attached to more than one ScrollPosition.
The Scrollbar requires a single ScrollPosition in order to be painted.
When Scrollbar.thumbVisibility is true, the associated ScrollController must only have one
ScrollPosition attached.
If a ScrollController has not been provided, the PrimaryScrollController is used by default on
mobile platforms for ScrollViews with an Axis.vertical scroll direction.
More than one ScrollView may have tried to use the PrimaryScrollController of the current context.
ScrollView.primary can override this behavior.

When the exception was thrown, this was the stack:
#0      RawScrollbarState._debugCheckHasValidScrollPosition.<anonymous closure>
(package:flutter/src/widgets/scrollbar.dart:1504:9)
#1      RawScrollbarState._debugCheckHasValidScrollPosition (package:flutter/src/widgets/scrollbar.dart:1532:6)
#2      RawScrollbarState._debugScheduleCheckHasValidScrollPosition.<anonymous closure>
(package:flutter/src/widgets/scrollbar.dart:1427:14)
#3      SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1438:15)
#4      SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1365:11)
#5      SchedulerBinding._handleDrawFrame (package:flutter/src/scheduler/binding.dart:1204:5)
#6      _invoke (dart:ui/hooks.dart:331:13)
#7      PlatformDispatcher._drawFrame (dart:ui/platform_dispatcher.dart:444:5)
#8      _drawFrame (dart:ui/hooks.dart:303:31)
════════════════════════════════════════════════════════════════════════════════════════════════════

make item in employee account not showing here

### [debug page/ debug service]
- Global variables section, not see well, cant scroll

### [cashier page]
- Got error bottom 100 overflow, or maybe we can change font size based on size?
- For confirm payment, maybe need to make more responsive to mobile size (or using y-scroll)
- for set also need to relayout to make it more responsive to the phone, maybe can make font size responsive with phone size
