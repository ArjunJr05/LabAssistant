# Tab Switch Detection Implementation

## Overview
This document outlines the complete implementation of tab switch detection functionality for the Lab Assistant application. The system detects when students switch tabs during exercises and implements a three-strike policy for malpractice detection.

## Features Implemented

### 1. Database Schema Updates
- **New Columns Added to `submissions` table:**
  - `ismalpractice` (BOOLEAN): Tracks if a submission is marked as malpractice
  - `tabswitch` (INTEGER): Counts the number of tab switches for each exercise session

### 2. Backend Implementation

#### Socket.IO Events
- **`tab-switch-detected`**: Emitted by client when tab switch is detected
- **`student-tab-switch`**: Broadcasted to admin for real-time monitoring

#### API Endpoints
- **`POST /api/student/update-tab-switch`**: Updates tab switch count for exercises
- **`GET /api/student/malpractice-exercises`**: Retrieves exercises marked as malpractice

#### Server Logic
- Automatic malpractice marking when tab switch count reaches 3
- Real-time broadcasting to admin dashboard
- Database persistence of tab switch events

### 3. Frontend Implementation

#### Code Editor Screen (`code_editor_screen.dart`)
- **Tab Switch Detection**: Uses HTML5 Visibility API and Window focus/blur events
- **Warning System**: 
  - 1st switch: Warning dialog
  - 2nd switch: Final warning dialog
  - 3rd switch: Exercise blocked, marked as malpractice
- **Visual Indicators**: Blocked exercises show appropriate UI states
- **Prevention**: Blocked exercises cannot be run or submitted

#### Student Dashboard (`students_screen.dart`)
- **Visual Indicators**: 
  - Malpractice exercises shown with red color scheme
  - Red border, red gradient, and block icon
  - "MALPRACTICE" badge instead of "COMPLETED"
- **Access Control**: Malpractice exercises cannot be opened
- **Real-time Updates**: Malpractice status loaded and displayed

#### Admin Dashboard (`admin_dashboard.dart`)
- **Real-time Notifications**: 
  - Warning notifications for 1st and 2nd tab switches
  - Critical alerts for malpractice detection (3rd switch)
- **Detailed Information**: Dialog showing student details and malpractice reason
- **Visual Feedback**: Color-coded notifications (orange for warnings, red for malpractice)

### 4. Tab Switch Detection Logic

#### Detection Methods
1. **Visibility API**: Detects when browser tab becomes hidden
2. **Window Focus/Blur**: Backup detection for application switching
3. **Event Listeners**: Properly managed with cleanup on component disposal

#### Three-Strike Policy
- **Strike 1**: Warning dialog, tab switch recorded
- **Strike 2**: Final warning dialog, tab switch recorded
- **Strike 3**: Exercise blocked, marked as malpractice, student cannot continue

#### Data Flow
1. Client detects tab switch → Updates local count
2. Sends socket event to server → Real-time admin notification
3. Calls API to update database → Persistent storage
4. Server broadcasts to admin → Live monitoring
5. Exercise blocked if count ≥ 3 → Prevention mechanism

### 5. Security Features

#### Prevention Mechanisms
- Code execution blocked for malpractice exercises
- Submission blocked for malpractice exercises
- Visual indicators prevent confusion
- Database-level tracking for audit trails

#### Admin Monitoring
- Real-time alerts for all tab switch events
- Detailed malpractice information
- Historical data through database queries
- Visual dashboard indicators

### 6. User Experience

#### Student Experience
- Clear warnings before blocking
- Visual feedback on exercise status
- Informative error messages
- Graceful degradation when blocked

#### Admin Experience
- Real-time monitoring capabilities
- Immediate malpractice alerts
- Detailed information dialogs
- Historical tracking through database

## Technical Implementation Details

### Database Schema
```sql
-- Added to submissions table
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS ismalpractice BOOLEAN DEFAULT false;
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS tabswitch INTEGER DEFAULT 0;
```

### Key Files Modified
1. **Backend:**
   - `backend/server.js` - Socket events and database schema
   - `backend/routes/student.js` - API endpoints for tab switch tracking

2. **Frontend:**
   - `lib/screens/code_editor_screen.dart` - Tab detection and blocking
   - `lib/screens/students_screen.dart` - Visual indicators and access control
   - `lib/screens/admin_dashboard.dart` - Real-time monitoring and alerts
   - `lib/services/api_services.dart` - API methods for malpractice data

### Socket Events Flow
```
Student Tab Switch → Client Detection → Socket Emit → Server Broadcast → Admin Notification
                                    ↓
                                API Call → Database Update → Persistent Storage
```

## Testing Recommendations

### Manual Testing
1. **Basic Tab Switch Detection:**
   - Open exercise in student interface
   - Switch to another tab/application
   - Verify warning dialog appears
   - Repeat to test 3-strike policy

2. **Admin Monitoring:**
   - Have admin dashboard open
   - Perform tab switches as student
   - Verify real-time notifications appear
   - Test malpractice dialog functionality

3. **Database Persistence:**
   - Check submissions table for updated counts
   - Verify malpractice flag is set correctly
   - Test API endpoints directly

### Edge Cases
- Multiple rapid tab switches
- Browser refresh during exercise
- Network connectivity issues
- Admin dashboard not connected

## Future Enhancements

### Possible Improvements
1. **Configurable Thresholds**: Allow admin to set custom tab switch limits
2. **Grace Period**: Implement time-based forgiveness for accidental switches
3. **Detailed Analytics**: Enhanced reporting on malpractice patterns
4. **Appeal System**: Allow students to contest malpractice flags
5. **Browser Compatibility**: Extended support for different browsers

### Security Enhancements
1. **Client-Side Validation**: Additional checks to prevent tampering
2. **Encrypted Communication**: Secure socket events
3. **Audit Logging**: Comprehensive logging of all malpractice events
4. **Admin Controls**: Ability to manually override malpractice flags

## Conclusion

The tab switch detection system provides comprehensive monitoring and prevention of malpractice during online exercises. The implementation includes real-time detection, progressive warnings, automatic blocking, and administrative oversight. The system maintains data integrity through database persistence and provides clear user feedback throughout the process.

The three-strike policy balances security with user experience, allowing for accidental tab switches while preventing deliberate cheating attempts. The real-time admin monitoring ensures immediate awareness of potential malpractice events.
